<cfcomponent
	displayname="SSIS Package Explorer"
	output="true"
	hint="">


	<!--- Set up the application. --->
	<CFSET THIS.Name="SSISPackageExplorer">
	<CFSET THIS.ApplicationTimeout=CreateTimeSpan( 1, 0, 0, 0 ) >
	<CFSET THIS.SessionManagement=false>
	<CFSET THIS.SetClientCookies=false>
	<CFSET THIS.Serialization.preservecaseforstructkey=true>
		
	<!--- Define the page request properties. --->
	<cfsetting requesttimeout="30" showdebugoutput="false" enablecfoutputonly="true"/>

	<cffunction
		name="OnApplicationStart"
		access="public"
		returntype="boolean"
		output="false"
		hint="Fires when the application is first created.">

		<CFIF StructKeyExists(Application,"Probes") EQ "NO">
			<!--- Create the probe structure --->
			<CFSET Application.Probes=StructNew("ordered")>
			<!--- Search for any saved probes and load --->
			<CFDIRECTORY action="list" directory="#ExpandPath('.')#/Probes" name="Probes" type="dir">

			<CFSET Probe.Run=StructNew("ordered")>
			<CFSET Probe.Run.Start="1970-01-01 00:00:00">
			<CFSET Probe.Run.End="1970-01-01 00:00:00">
			<CFSET Probe.Run.ExecMS=0>
			<CFSET Probe.Run.Error="Probe has not ran yet">

			<CFLOOP index="CR" from="1" to="#Probes.RecordCount#">
				<CFIF FileExists("#Probes.Directory[CR]#/#Probes.Name[CR]#/Disabled.txt") EQ "NO">
					<CFSET Application.Probes[Probes.Name[CR]]=Duplicate(Probe)>
				</CFIF>
			</CFLOOP>
		</CFIF>

		<!--- Locate the location of Powershell --->
		<CFSET CheckPaths=ArrayNew(1)>
		<CFSET CheckPaths[1]=Server.System.Environment.ProgramFiles & "\9\pwsh.exe">
		<CFSET CheckPaths[2]=Server.System.Environment.ProgramFiles & "\8\pwsh.exe">
		<CFSET CheckPaths[3]=Server.System.Environment.ProgramFiles & "\7\pwsh.exe">
		<CFSET CheckPaths[3]=Server.System.Environment.ProgramFiles & "\6\pwsh.exe">
		<CFSET CheckPaths[3]=Server.System.Environment.ProgramFiles & "\5\pwsh.exe">
		<CFSET CheckPaths[4]=Server.System.Environment.Windir & "\System32\WindowsPowerShell\v1.0\powershell.exe">
		<CFSET CheckPaths[5]=Server.System.Environment.Windir & "\SysWOW64\WindowsPowerShell\v1.0\powershell.exe">
		<CFSET Application.Powershell="">
		<CFLOOP index="CR" from="1" to="#ArrayLen(CheckPaths)#">
			<CFIF FileExists(CheckPaths[CR])>
				<CFSET Application.Powershell=CheckPaths[CR]>
				<CFBREAK>
			</CFIF>
		</CFLOOP>

		<!--- Return out. --->
		<cfreturn true />
	</cffunction>



	<cffunction
		name="OnRequest"
		access="public"
		returntype="void"
		output="true"
		hint="Fires after pre page processing is complete.">

		<!--- Define arguments. --->
		<cfargument
			name="TargetPage"
			type="string"
			required="true"
			/>

		<CFSET RootDir=Replace(ExpandPath("."),"\","/","All")>
		<!--- Handle if running under a subdirectory of the app root --->
		<CFSET Loc=FindNoCase("/SSISPackageExplorer/",RootDir)>
		<CFIF Loc GT 0>
			<CFSET RootDir=Left(RootDir,Loc + 19)>
		</CFIF>

		<CFSET RootWebDir=ListDeleteAt(CGI.Script_Name,ListLen(CGI.Script_Name,"/"),"/")>

		<!--- Check for package export directories --->
		<CFIF DirectoryExists("#RootDir#/Exports") EQ "NO">
			<CFDIRECTORY action="create" directory="#RootDir#/Exports" mode="666">
		</CFIF>

		<CFINCLUDE template="config.cfm">
		<CFINCLUDE template="UDF.cfm">

		<!--- Include the requested page. --->
		<cfinclude template="#ARGUMENTS.TargetPage#">

		<!--- Return out. --->
		<cfreturn>
	</cffunction>


</cfcomponent>