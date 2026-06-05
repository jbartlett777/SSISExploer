<!--- Get Server Name --->
<CFQUERY name="DBServer" datasource="#DSN#">
	SELECT SERVERPROPERTY('ServerName') AS ServerName
</CFQUERY>
<!--- Fetch installed packages --->
<CFQUERY name="Packages" datasource="#DSN#">
	SELECT f.name as Folder, pr.name as Project, pa.name as Package, CONVERT(DATETIME,pr.last_deployed_time) as last_deployed_time
	FROM SSISDB.catalog.packages pa with (nolock)
	INNER JOIN SSISDB.catalog.projects pr with (nolock) on pr.project_id=pa.project_id
	INNER JOIN SSISDB.catalog.folders f with (nolock) on f.folder_id=pr.folder_id
	ORDER BY f.name, pr.name, pa.name
</CFQUERY>
<CFIF Packages.RecordCount EQ 0>
	<CFOUTPUT>
	Error: No packages detected. If the authenticated user has either the Sys Admin/SSIS Admin/SSIS Log Reader roles, then there are no packages installed.
	</div>
	</body>
	</html>
	</CFOUTPUT>
	<CFABORT>
</CFIF>

<!--- Check to see if any packages needs to be exported --->
<CFSET Exported=0>
<CFSET DBDir=REReplaceNoCase(DBServer.Servername,"[^A-Za-z0-9]","_","All")> <!--- Remove all non-alphanumeric characters --->
<CFSET DBDir=ReplaceRepeats(DBDir,"_")>
<CFSET ExportDir="#RootDir#/Exports/#DBDir#">
<CFIF DirectoryExists(ExportDir) EQ "NO">
	<CFDIRECTORY action="create" directory="#ExportDir#" mode="666">
</CFIF>
<CFLOOP index="CR" from="1" to="#Packages.RecordCount#">
	<CFSET Folder=Packages.Folder[CR]>
	<CFIF DirectoryExists("#ExportDir#/#Folder#") EQ "NO">
		<CFDIRECTORY action="create" directory="#ExportDir#/#Packages.Folder[CR]#" mode="666">
	</CFIF>
	<CFSET PackageDir=Packages.Project[CR]>
	<CFIF DirectoryExists("#ExportDir#/#Folder#/#PackageDir#") EQ "NO">
		<CFDIRECTORY action="create" directory="#ExportDir#/#Folder#/#PackageDir#" mode="666">
	</CFIF>
	<CFSET Package=DateTimeFormat(Packages.last_deployed_time[CR],"yyyy-mm-dd_HH-mm-nn")>
	<CFSET Export="#ExportDir#/#Folder#/#PackageDir#/#Package#">
	<CFSET ExportPackage=0>
	<CFIF DirectoryExists("#Export#") EQ "NO" OR (DirectoryExists("#Export#") AND FileExists("#Export#/#PackageDir#.ispac") EQ "NO")>
		<CFSET ExportPackage=1>
	</CFIF>
<CFIF FindNoCase("ztest",Export)>
<CFSET ExportPackage=1> <!--- ****************** FORCE REBUILD ********************* --->
</CFIF>
<CFSET ExportPackage=1> <!--- ****************** FORCE REBUILD ********************* --->
	<CFIF ExportPackage>
		<CFIF DirectoryExists("#Export#") EQ "NO">
			<CFDIRECTORY action="create" directory="#Export#" mode="666">
		</CFIF>
		<CFSET Exported=1>
		<CFOUTPUT>#TS()# #EncodeForHTML(Folder)#/#EncodeForHTML(Packages.Package[CR])#: Exporting</CFOUTPUT><CFFLUSH>
		<!--- Extract package binary from database --->
		<CFQUERY name="PackageBinary" datasource="#DSN#">
			EXEC SSISDB.catalog.get_project <cfqueryparam CFSQLType="CF_SQL_VARCHAR" value="#Folder#">,
											<cfqueryparam CFSQLType="CF_SQL_VARCHAR" value="#PackageDir#">
		</CFQUERY>
		<CFOUTPUT>. Saving</CFOUTPUT><CFFLUSH>
		<CFFILE action="write" file="#Export#/#PackageDir#.ispac" output="#PackageBinary.Project_Stream#">
		<!--- Unzip package --->
		<CFOUTPUT>. Unpacking</CFOUTPUT><CFFLUSH>
		<CFTRY>
			<cfzip action="unzip" destination="#Export#" file="#Export#/#PackageDir#.ispac">
			<CFCATCH Type="Any">
				<CFOUTPUT>
				<font color="Red">. Error unpacking #Export#/#PackageDir#.ispac</font> [#CFCatch.Detail#]<br>
				</CFOUTPUT>
				<!--- Check to see if blob is enabled by the file size. If it's 64KB in size, it's not --->
				<CFSET FI=GetFileInfo("#Export#/#PackageDir#.ispac")>
				<CFIF FI.Size EQ 64000>
					<CFOUTPUT>
					<hr>
					Extracted file is an invalid file and 64K, verify that BLOB is set on Datasource "#DSN#"
					</CFOUTPUT>
					<CFFILE action="delete" file="#Export#/#PackageDir#.ispac">
					<CFABORT>
				</CFIF>
				<!--- Remove file --->
				<CFIF FileExists("#Export#/#PackageDir#.ispac.bad")>
					<CFFILE action="Delete" file="#Export#/#PackageDir#.ispac.bad">
				</CFIF>
				<CFFILE action="rename" source="#Export#/#PackageDir#.ispac" destination="#Export#/#PackageDir#.ispac.bad">
				<CFCONTINUE>
			</CFCATCH>
		</CFTRY>
		<!--- Loop over exported files and look for URL encoded files and rename if found --->
		<CFDIRECTORY action="list" directory="#Export#" type="file" recurse="true" name="PackageFiles">
		<CFLOOP index="FileIdx" from="1" to="#PackageFiles.RecordCount#">
			<CFSET DecodedFN=URLDecode(PackageFiles.Name[FileIdx])>
			<CFIF DecodedFN NEQ PackageFiles.Name[FileIdx]>
				<!--- Rename file --->
				<CFFILE action="Rename"
						source="#PackageFiles.Directory[FileIdx]#/#PackageFiles.Name[FileIdx]#"
						destination="#PackageFiles.Directory[FileIdx]#/#DecodedFN#">
			</CFIF>
		</CFLOOP>
		<CFOUTPUT>. Analyzing</CFOUTPUT>

		<!--- Load in the dtsx files --->
		<CFDIRECTORY action="list" directory="#Export#" filter="*.dtsx" type="file" name="DTSXFiles">
		<CFLOOP index="DTSXIdx" from="1" to="#DTSXFiles.RecordCount#">
			<CFSET OK=0>
			<CFSET DTSX=DTSXFiles.Directory[DTSXIdx] & "/" & DTSXFiles.Name[DTSXIdx]>
			<CFSET MermaidFN=ListDeleteAt(DTSX,ListLen(DTSX,"."),".")>
			<CFIF FileExists(DTSX)>
				<CFSET OK=1>
			</CFIF>
			<CFIF NOT OK>
				<CFOUTPUT>. <font color="Red">Unable to locate #EncodeForHTML(DTSX)#</font><br></CFOUTPUT>
				<CFCONTINUE>
			</CFIF>
			<CFFILE action="Read" file="#DTSX#" variable="Obj">

			<CFSET Obj=XMLParse(Obj)>
			<CFSET Package=ParseDTSX(Obj)>
			<CFSET Mermaid=BuildMermaidChart(Package)>
			<CFSET NodeList=BuildNodeList(Package)>

			<CFOUTPUT>. Saving data files</CFOUTPUT><CFFLUSH>
			<CFFILE action="write" file="#MermaidFN#.json" output="#FormatJSON(SerializeJSON(Package))#" addnewline="no" mode="666">
			<CFFILE action="write" file="#MermaidFN#.nodes" output="#NodeList#" addnewline="no" mode="666">
			<CFFILE action="write" file="#MermaidFN#.mermaid" output="#Mermaid#" addnewline="no" mode="666">
		</CFLOOP>
		<!---
		<cfoutput><br><textarea cols="255" rows="#Listlen(Mermaid,Chr(10))+2#">#EncodeForHTML(Mermaid)#</textarea></cfoutput>
		<cfdump var=#Package#>
		<cfdump var=#obj#>
		<cfdump var=#ToString(Obj["XmlRoot"]["DTS:DesignTimeProperties"])#>
		<cfabort>
		--->

		<CFOUTPUT>. Done.<br></CFOUTPUT>
	</CFIF>

</CFLOOP>