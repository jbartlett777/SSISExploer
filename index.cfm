<!---
Sample packages:
https://www.microsoft.com/en-us/download/details.aspx?id=56827

--->

<CFSET Exec=ArrayNew(1)> <!--- Global Var for GetExecutables --->
<CFSET ExecRef=StructNew()>


<CFOUTPUT>
<!DOCTYPE html>
<html>
<head>
	<title>SSIS Package explorer</title>
	<!--- https://cdnjs.com/libraries --->
	<!--- JQuery/UI --->
	<script src="https://cdnjs.cloudflare.com/ajax/libs/jquery/3.7.1/jquery.min.js" integrity="sha512-v2CJ7UaYy4JwqLDIrZUI/4hqeoQieOmAZNXBeQyjo21dadnwR+8ZaIJVT8EE2iyI61OV8e6M8PP2/4hpQINQ/g==" crossorigin="anonymous" referrerpolicy="no-referrer"></script>
	<script src="https://cdnjs.cloudflare.com/ajax/libs/jqueryui/1.14.1/jquery-ui.min.js" integrity="sha512-MSOo1aY+3pXCOCdGAYoBZ6YGI0aragoQsg1mKKBHXCYPIWxamwOE7Drh+N5CPgGI5SA9IEKJiPjdfqWFWmZtRA==" crossorigin="anonymous" referrerpolicy="no-referrer"></script>
	<!--- Fancytree --->
	<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/jquery.fancytree/2.38.5/skin-xp/ui.fancytree.min.css" integrity="sha512-tIFiI2MOsn+7JGIDIMO6h5+owmO3OHYrCof8ZdzG/Pam9dxbTzIi8UbOfU61r9gDA81RLGY+J0q6oj+vQb5dEg==" crossorigin="anonymous" referrerpolicy="no-referrer" />
	<script src="https://cdnjs.cloudflare.com/ajax/libs/jquery.fancytree/2.38.5/jquery.fancytree-all.min.js" integrity="sha512-kgah39Jkg6h15hPhOzZQcqPHZjjS5ZcHs6S31IB0YI97PGKDmz5fJuyoqb9YgjYmEcwtAQg5X29OsCtAS47HxA==" crossorigin="anonymous" referrerpolicy="no-referrer"></script>
	<!--- Mermaid charts --->
	<script src="https://cdnjs.cloudflare.com/ajax/libs/mermaid/11.12.0/mermaid.min.js" integrity="sha512-5TKaYvhenABhlGIKSxAWLFJBZCSQw7HTV7aL1dJcBokM/+3PNtfgJFlv8E6Us/B1VMlQ4u8sPzjudL9TEQ06ww==" crossorigin="anonymous" referrerpolicy="no-referrer"></script>
	<style type="text/css">
	 /* Override Fancytree border */
	ul.fancytree-container {
		border: none;
	}
	</style>
</head>
<body>

<div id="Status">
</CFOUTPUT>

<!---<CFDIRECTORY action="delete" directory="C:\CommandBox\CFM\SSISPackageExplorer\Exports\WACDTL03JB9413" recurse="true">--->

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
		<!---
		<cfstoredproc procedure="SSISDB.catalog.get_project" datasource="#DSN#">
			<cfprocparam cfsqltype="CF_SQL_VARCHAR" type="in" value="#Folder#">
			<cfprocparam cfsqltype="CF_SQL_VARCHAR" type="in" value="#PackageDir#">
			<cfprocresult name="PackageBinary">
		</cfstoredproc>
		--->
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
			<CFSET Package=GetExecutables(Obj)>
			<CFSET Mermaid=BuildMermaidChart(Package)>

			<CFOUTPUT>. Saving data files</CFOUTPUT><CFFLUSH>
			<CFFILE action="write" file="#Export#/Package.json" output="#SerializeJSON(Package)#" addnewline="no" mode="666">
			<CFFILE action="write" file="#MermaidFN#.Mermaid" output="#Mermaid#" addnewline="no" mode="666">
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

<cfset exported=1>
<CFIF Exported EQ 1 OR FileExists("#RootDir#/Exports/FancyTree.json") EQ "NO">
	<CFOUTPUT>#TS()# Building Package Tree...</CFOUTPUT><CFFLUSH>
	<CFSET FancyTree=BuildPackageTree("#RootDir#/Exports")>
	<CFIF ArrayLen(FancyTree) EQ 1>
		<!--- Auto expand root node if only one --->
		<CFSET FancyTree[1]["expanded"]="true">
	</CFIF>
	<CFSET FancyTreeJSON=SerializeJSON(FancyTree)>
	<CFOUTPUT>Done.<br></CFOUTPUT>
	<CFFILE action="write" file="#RootDir#/Exports/FancyTree.json" output="#FancyTreeJSON#" addnewline="NO" mode="666">
</CFIF>
<CFOUTPUT>
</div>
<CFFILE action="read" file="#RootDir#/Exports/FancyTree.json" variable="FancyTreeJSON">

<script>
document.getElementById('Status').style.display='none';
var Code=#FancyTreeJSON#;
function ShowTree() {
	$("##tree").fancytree({
/*
		extensions: ["filter"],
		// Define filter-extension options:
		filter: {
			autoExpand: true,
			highlight: false,
			leavesOnly: true,
			mode: "hide",
			nodata: true
		},
*/
		click: function(event, data) {
//			var ID=data.node.key;
//			if (ID.substr(0,1) == 'P') ViewCode(ID);
		},
		activate: function(event, data) {
			var ID=data.node.key;
			var path=data.node.data.path;
			if (ID.substr(0,1) == 'P') ViewCode(path);
		},
		source: Code
	});
};	


mermaid.initialize({ startOnLoad: false });

let ChartCounter = 0;

function RenderChart(chartText) {
	const container = document.getElementById("chart");

	const id = "chart" + (++ChartCounter);

	mermaid.render(id, chartText).then(({ svg }) => {
		container.innerHTML = svg;
	});
}

function ViewCode(Path) {
	$.ajax({
		type: 'POST',
		url: 'ajax_Mermaid.cfm?Mermaid='+Path,
		success: function(data) {
			RenderChart(data);
		},
		error: function(event, request, settings) {
			alert('failed ['+event+']['+request+']['+settings+']');
		}
	});
}
//mermaid.initialize({ startOnLoad: true });
</script>

<style type="text/css">
.home-container10 {
	width: 100%;
	/*display: flex;
	flex-direction: column;*/
	min-height: 100vh;
	align-items: center;
}
 
.home-container11 {
  flex: 0 0 auto;
  width: 100vw;
  display: flex;
  align-items: flex-start;
}
 
.home-container12 {
  flex: 0 0 auto;
  width: auto;
  height: 100vh;
  display: flex;
  align-items: flex-start;
  flex-direction: column;
}

.home-container18 {
  flex: 1;
  overflow: auto;
}

.home-container19 {
  flex: 0 0 auto;
  display: flex;
  min-width: 25px;
  min-height: 25px;
  align-items: flex-start;
  flex-direction: column;
}

.TreeDiv {
  flex: 1;
  display: flex;
  overflow: auto;
  align-items: flex-start;
  flex-direction: column;
}
 
.Content {
  font-size: 16px;
  font-family: Inter;
  font-weight: 400;
  line-height: 1.15;
  text-transform: none;
  text-decoration: none;
}

.home-text {
  width: 100%;
  margin: 3px;
}
</style>

<!--- Page display --->
<div>
	<div class="home-container10">
	<div class="home-container11">
		<div class="home-container12">
		<div class="home-container18">
			<div id="tree" class="home-container19"></div>
		</div>
		</div>
		<div class="home-container20">
		<span id="code" class="home-text">
			<div id="chart"></div>
		</span>
		</div>
	</div>
	</div>
</div>


<script>
ShowTree();
const chart = `
stateDiagram-v2
  direction TB

  x:Select a .dtsx file
`;
RenderChart(chart);
</script>

</CFOUTPUT>

<cfscript>
// Builds Fancytree object, expects the package export path to be passed in
public array function BuildPackageTree(required string Path) {
	var FancyTree=ArrayNew(1);
	var Dir=""; // Directory
	var FT=0;
	var DirIdx=0;
	var DTSXCheck="";
	var i=0;
	var RootDir=Replace(ExpandPath("."),"\","/","All");
	var Firstpass=false; // If true, first call into function

	if (DirectoryExists(Arguments.Path) EQ false) {
		// Bad path, return empty array
		return FancyTree;
	}

	// Define Request.BuildPackageTree_Key for FancyTree PK
	if (StructKeyExists(Request,"BuildPackageTree_Key") EQ "NO") {
		Request.BuildPackageTree_Key=0;
		FirstPass=true;
	}

	// Check current directory for dtsx files
	DTSXCheck=DirectoryList(path=Arguments.Path, listinfo="name", Type="File", Filter="*.dtsx");
	if (ArrayLen(DTSXCheck)) {
		// Add child items for dtsx files and return (end of tree)
		for (i=1; i LTE ArrayLen(DTSXCheck); i++) {
			Request.BuildPackageTree_Key=Request.BuildPackageTree_Key + 1;
			FT=ArrayLen(FancyTree) + 1;
			FancyTree[FT]=StructNew("ordered");
			FancyTree[FT].folder=false;
			FancyTree[FT].key="P" & Request.BuildPackageTree_Key;
			FancyTree[FT].path=Replace(Replace(Arguments.Path & "/" & DTSXCheck[i],"\","/","All"),RootDir,"");
			FancyTree[FT].title=URLDecode(DTSXCheck[i]);
		}
		return FancyTree;
	}

	Dir=DirectoryList(path=Arguments.Path, listinfo="query", type="Dir");

	// Loop over directory
	for (DirIdx=1; DirIdx LTE Dir.RecordCount; DirIdx++) {
		if (Dir.Type[DirIdx] EQ "Dir") {
			// Check for DTSX in child dir
			FolderFlag="true";
			DTSXCheck=DirectoryList(path=Dir.Directory[DirIdx] & "/" & Dir.Name[DirIdx], listinfo="name", Type="File", Filter="*.dtsx");
			if (ArrayLen((DTSXCheck))) FolderFlag="false";
			Request.BuildPackageTree_Key=Request.BuildPackageTree_Key + 1;
			FT=ArrayLen(FancyTree) + 1;
			FancyTree[FT]=StructNew("ordered");
			FancyTree[FT].folder=true;
			FancyTree[FT].key="F" & Request.BuildPackageTree_Key;
			if (ArrayLen(DTSXCheck) EQ 0) {
				FancyTree[FT].title=Dir.Name[DirIdx];
			} else {
				FancyTree[FT].title=DateTimeFormat(ListFirst(Dir.Name[DirIdx],"_") & " " & Replace(ListLast(Dir.Name[DirIdx],"_"),"-",":","All"), "yyyy-mm-dd HH:nn:ss");
			}
			FancyTree[FT].children=BuildPackageTree(Dir.Directory[DirIdx] & "/" & Dir.Name[DirIdx]);
		}
	}

	return FancyTree;
}

// Recurses through the DTSC XML and extracts information into a struct
// XML Reference: https://learn.microsoft.com/en-us/openspecs/sql_data_portability/ms-dtsx/235600e9-0c13-4b5b-a388-aa3c65aec1dd
public any function GetExecutables(required xml DTSX) {
	var Node=""; // Placeholder
	var Key=""; // Used for looping over structs
	var Config=""; // Used for remapping XML to Struct
	var Child=""; // Placeholder
	var Child2=""; // Placeholder
	var ChildIdx=0; // Loop variables
	var i=0;
	var x=0;
	var y=0;
	var z=0;
	var c=0;

	var Package=StructNew();
	// If at the root, dive into it
	if (structKeyExists(Arguments.DTSX,"XmlRoot")) return GetExecutables(Arguments.DTSX.XmlRoot);

	// Recurse for executables
	if (Arguments.DTSX.XmlName EQ "DTS:Executables") {
		// All of the children here are the steps to execute, recurse into them
		Package=ArrayNew(1);
		for (ChildIdx=1; ChildIdx LTE ArrayLen(Arguments.DTSX.XmlChildren); ChildIdx++) {
			Package[ChildIdx]=GetExecutables(Arguments.DTSX.XmlChildren[ChildIdx]);
		}
	}

	if (Arguments.DTSX.XmlName EQ "DTS:PrecedenceConstraints") {
		Package=ArrayNew(1);
		for (ChildIdx=1; ChildIdx LTE ArrayLen(Arguments.DTSX.XmlChildren); ChildIdx++) {
			Package[ChildIdx]=Arguments.DTSX.XmlChildren[ChildIdx].XmlAttributes;
		}
	}

	if (Arguments.DTSX.XmlName EQ "DTS:Executable") {
		if (StructKeyExists(Arguments.DTSX.XmlAttributes,"DTS:ExecutableType")) {
			for (Key in StructKeyList(Arguments.DTSX.XmlAttributes)) {
				Package[Key]=Arguments.DTSX.XmlAttributes[Key];
			}

			for (ChildIdx=1; ChildIdx LTE ArrayLen(Arguments.DTSX.XmlChildren); ChildIdx++) {
				if (Arguments.DTSX.XmlChildren[ChildIdx].XmlName EQ "DTS:Executables") {
					Package.Executables=GetExecutables(Arguments.DTSX.XmlChildren[ChildIdx]);

				} else if (Arguments.DTSX.XmlChildren[ChildIdx].XmlName EQ "DTS:PrecedenceConstraints") {
					Package.Relationships=GetExecutables(Arguments.DTSX.XmlChildren[ChildIdx]);

				} else if (ListFindNoCase("DTS:ConnectionManagers,DTS:Configurations,DTS:LogProviders,DTS:Variables,DTS:LoggingOptions",Arguments.DTSX.XmlChildren[ChildIdx].XMLName)) {
					Package[Arguments.DTSX.XmlChildren[ChildIdx].XMLName]=Arguments.DTSX.XmlChildren[ChildIdx];
				}
			}
		}
	}

	// Parse out Package structures
	if (IsStruct(Package)) {
		// Remove unneeded objects
		for (Key in "DTS:LogProviders,DTS:LoggingOptions,xmlns:DTS") {
			if (StructKeyExists(Package,Key)) StructDelete(Package,Key);
		}

		if (StructKeyExists(Package,"DTS:Configurations")) {
			Config=ArrayNew(1);
			for (i=1; i LTE ArrayLen(Package["DTS:Configurations"].XmlChildren); i++) {
				Child=Package["DTS:Configurations"].XmlChildren[i].XmlAttributes;
				Config[i]=StructNew("casesensitive");
				if (StructKeyExists(Child,"DTS:ConfigurationVariable")) {
					Config[i][Child["DTS:ObjectName"]]=Child["DTS:ConfigurationVariable"];
				} else {
					Config[i][Child["DTS:ObjectName"]]="";
				}
			}
			Package["DTS:Configurations"]=Config;
		}

		if (StructKeyExists(Package,"DTS:ConnectionManagers")) {
			Config=ArrayNew(1);
			for (i=1; i LTE ArrayLen(Package["DTS:ConnectionManagers"].XmlChildren); i++) {
				Child=Package["DTS:ConnectionManagers"].XmlChildren[i];
				Config[i]=StructNew();
				for (x=1; x LTE ArrayLen(Child.XmlChildren); x++) {
					if (Child.XmlChildren[x].XmlName EQ "DTS:PropertyExpression") Config[i][Child.XmlChildren[x].XmlAttributes["DTS:Name"]]=Child.XmlChildren[x].XmlText;
					if (Child.XmlChildren[x].XmlName EQ "DTS:ObjectData") {
						// Loop over ObjectData children
						for (y=1; y LTE ArrayLen(Child.XmlChildren[x].XmlChildren); y++) {
							// Set Connection attributes
							Config[i].ConnectionManager=Child.XmlChildren[x].XmlChildren[y].XmlAttributes;
							// Loop over Connection
							for (z=1; z LTE ArrayLen(Child.XmlChildren[x].XmlChildren[y].XmlChildren); z++){
								if (Child.XmlChildren[x].XmlChildren[y].XmlChildren[z].XmlName EQ "DTS:FlatFileColumns") {
									// Gather text file column information
									Config[i].Columns=ArrayNew(1);
									for (c=1; c LTE ArrayLen(Child.XmlChildren[x].XmlChildren[y].XmlChildren[z].XmlChildren); c++) {
										Child2=Child.XmlChildren[x].XmlChildren[y].XmlChildren[z].XmlChildren[c];
										Config[i].Columns[c]=StructNew();
										for (Key in StructKeyList(Child2.XmlAttributes)) {
											Config[i].Columns[c][ListRest(Key,":")]=Child2.XmlAttributes[Key];
										}
									}
								}
							}
						}
					}
				}
			}
			Package["DTS:ConnectionManagers"]=Config;
		}

		if (StructKeyExists(Package,"DTS:Variables")) {
			Config=StructNew();
			// Loop over variables
			for (i=1; i LTE ArrayLen(Package["DTS:Variables"].XmlChildren); i++) {
				Child=Package["DTS:Variables"].XmlChildren[i];
				/*
				DataType reference
				1	Null value.
				2	Two-byte integer.
				3	Four-byte integer.
				4	Four-byte real.
				5	Eight-byte real.
				6	Currency.
				7	Date.
				8	BSTR.

				11	Boolean.
				13	Object.
				14	Decimal.
				16	One-byte integer.
				17	One-byte unsigned integer.
				18	Two-byte unsigned integer.
				19	Four-byte unsigned integer.
				20	Eight-byte integer.
				21	Eight-byte unsigned integer.
				22	Integer.
				23	Unsigned integer.
				64	An unsigned 64-bit date/time value. Represents the number of 100 nanosecond units since the start of January 1, 1601.
				72	GUID.
				129	A variable-length string with a specified maximum length.
				130	Null-terminated Unicode character string with maximum length of 8000 characters.
				131	Numeric
				133	DbDate, a structure that consists of year, month, day.
				134	DbTime, a structure that consists of hour, minute, second.
				135	DbTimeStamp, a structure that consists of year, month, day, hour, minute, seconds, and fractional parts.
				139	Varnumeric, a structure that can hold very large numeric values.
				145	Same as value 134, but includes fractional seconds.
				146	Same as value 135, but includes a time zone offset.
				*/
				if (ListFind("1,2,3,4,5,6,7,8,11,14,16,17,18,19,20,21,22,23,64,72,129,130,131,133,134,135,139,145,146",Child.XmlChildren[1].XmlAttributes["DTS:DataType"])) // No formatting needed
					Config[Child.XmlAttributes["DTS:Namespace"] & "." & Child.XmlAttributes["DTS:ObjectName"]]=Child.XmlChildren[1].XmlText;
			}
			Package["DTS:Variables"]=Config;
		}

	}

	return Package;
}

// Takes the output from GetExecutables and builds a Mermaid string
// Do not pass an argument for parameter "RecursedID", it is used internally
public string function BuildMermaidChart(required struct Package, boolean Recursed=false) {
	var Chart="";
	var i=0;
	var FromNode="";
	var ToNode="";
	var NodeName="";
	var Label="";

	// Request.BuildMermaidChart_DisabledNodes is used to track execute nodes that have the disabled flag set
	if (StructKeyExists(Request,"BuildMermaidChart_DisabledNodes") EQ "NO") Request.BuildMermaidChart_DisabledNodes="";

	if (Arguments.Recursed EQ 0) {
		// First time through the function
		Chart="---" & Chr(10) &
			  "config:" & Chr(10) &
			  "  theme: redux" & Chr(10) &
			  "  look: neo" & Chr(10) &
			  "---" & Chr(10) &
			  "stateDiagram-v2" & Chr(10) &
			  "  direction TB" & Chr(10) & Chr(10);
	}

	// Render nodes
	for (i=1; i LTE ArrayLen(Package.Executables); i++) {
		if (Arguments.Recursed) Chart=Chart & "  ";
		NodeName="Node_" & REReplaceNoCase(Package.Executables[i]["DTS:refId"],"[^A-Z0-9]","","All");
		Chart=Chart & "  " & NodeName & ":" & Package.Executables[i]["DTS:ObjectName"] & Chr(10);

		// Check for disabled node
		if (StructKeyExists(Package.Executables[i],"DTS:Disabled") AND Package.Executables[i]["DTS:Disabled"] EQ "True")
			Request.BuildMermaidChart_DisabledNodes=ListAppend(Request.BuildMermaidChart_DisabledNodes,NodeName);
	}

	// Render relationships

	if (StructKeyExists(Package,"Relationships")) {
		// Loop over the relationships to align with the package
		for (i=1; i LTE ArrayLen(Package.Relationships); i++) {
			if (Arguments.Recursed) Chart=Chart & "  ";

			FromNode="Node_" & REReplaceNoCase(Package.Relationships[i]["DTS:From"],"[^A-Z0-9]","","All");
			ToNode="Node_" & REReplaceNoCase(Package.Relationships[i]["DTS:To"],"[^A-Z0-9]","","All");
			Label="";
			if (StructKeyExists(Package.Relationships[i],"DTS:Value") AND Package.Relationships[i]["DTS:Value"] EQ "1")
				Label=":Failure";

			Chart=Chart & "  " & FromNode & " --> " & ToNode & Label & Chr(10);
		}
	}

	if (StructKeyExists(Package,"Executables")) {
		// Check for nested executables
		for (i=1; i LTE ArrayLen(Package.Executables); i++) {
			if (StructKeyExists(Package.Executables[i],"Executables")) {
				NodeName="Node_" & REReplaceNoCase(Package.Executables[i]["DTS:refId"],"[^A-Z0-9]","","All");
				Chart=Chart & "  state " & NodeName & " {" & Chr(10);
				Chart=Chart & BuildMermaidChart(Package.Executables[i],true);
				Chart=Chart & "  }" & Chr(10);
			}
		}
	}

	// Append disabled node style if used but only on first call of this function
	if (Arguments.Recursed EQ false AND Request.BuildMermaidChart_DisabledNodes NEQ "") {
		Chart=Replace(Chart,"direction TB" & Chr(10),"direction TB" & Chr(10) & "  classDef Disabled color:##999,stroke:##999");
		Chart=Chart & "  class " & Request.BuildMermaidChart_DisabledNodes & " Disabled" & Chr(10);
		// Delete Request var
		StructDelete(Request,"BuildMermaidChart_DisabledNodes");
	}

	return Chart;
}
</cfscript>


<cfscript>



public any function XMLToStruct(required XML XMLObj, boolean CreateArrays=false) {
	var Node=StructNew("ordered-casesensitive");
	var Attribs=StructNew("ordered-casesensitive");
	var HoldNode="";
	var i=0; 
	var Key="";
	var AttribKey="";
	var AttribI=0;
	var tmp="";

	if (structKeyExists(XMLObj,"XmlRoot")) {
		if (Arguments.CreateArrays) {
			// Treat the root as an array and recurse past the root
			Node[XMLObj.XmlRoot.XmlName]=ArrayNew(1);
			Node[XMLObj.XmlRoot.XmlName][1]=XMLToStruct(XMLObj.XmlRoot, Arguments.CreateArrays);
		} else {
			// Recurfse past the root
			Node[XMLObj.XmlRoot.XmlName]=XMLToStruct(XMLObj.XmlRoot, Arguments.CreateArrays);
		}
		return Node;
	} else {
		if (ArrayLen(XMLObj.XmlChildren) EQ 0) {
			Node=XMLObj.XmlText.trim();
		} else {
			for (i=1; i LTE ArrayLen(XMLObj.XmlChildren); i++) {
				// Extract Node
				Key=XMLObj.XmlChildren[i].XmlName.trim();
				HoldNode=XMLToStruct(XMLObj.XmlChildren[i], Arguments.CreateArrays);
				if (StructKeyExists(Node,Key) EQ "NO")
				{
					if (Arguments.CreateArrays AND IsSimpleValue(HoldNode) EQ "NO") {
						// Set the node as an array
						Node[Key]=ArrayNew(1);
						Node[Key][1]=HoldNode;
					} else {
						// Set the node
						Node[Key]=HoldNode;
					}
				} else {
					if (IsArray(Node[Key]) EQ "NO") {
						// Key already exist, convert it to an array if not already one
						tmp=Node[Key];
						Node[Key]=ArrayNew(1);
						Node[Key][1]=tmp;
						if (StructKeyExists(Node,"#Key#.XmlAttributes")) {
							// Convert the attribs to an array
							tmp=Node["#Key#.XmlAttributes"];
							Node["#Key#.XmlAttributes"]=ArrayNew(1);
							Node["#Key#.XmlAttributes"][1]=tmp;
						}
					}
					// Append node
					AttribI=ArrayLen(Node[Key]) + 1;
					Node[Key][AttribI]=HoldNode;
				}
				// Check for Attributes
				if (StructCount(XMLObj.XmlChildren[i].XmlAttributes) GT 0) {
					// Extract node attributes
					Attribs=StructNew("ordered-casesensitive");
					for (AttribKey in StructKeyList(XMLObj.XmlChildren[i].XmlAttributes)) {
						Attribs[AttribKey]=XMLObj.XmlChildren[i].XmlAttributes[AttribKey];
					}
					if (StructKeyExists(Node,"#Key#.XmlAttributes") EQ "NO") {
						if (IsArray(Node[Key])) {
							// The main node is an array, set the attributes to be an array
							Node["#Key#.XmlAttributes"]=ArrayNew(1);
							Node["#Key#.XmlAttributes"][ArrayLen(Node[Key])]=Attribs;
						} else {
							// Set the attribs
							if (Arguments.CreateArrays) {
								// Create as an array
								Node["#Key#.XmlAttributes"]=ArrayNew(1);
								Node["#Key#.XmlAttributes"][1]=Attribs;
							} else {
								// Create as a struct
								Node["#Key#.XmlAttributes"]=Attribs;
							}
						}
					} else {
						if (IsArray(Node["#Key#.XmlAttributes"]) EQ "NO") {
							// Convert to an array
							tmp=Node["#Key#.XmlAttributes"];
							Node["#Key#.XmlAttributes"]=ArrayNew(1);
							Node["#Key#.XmlAttributes"][1]=tmp;
						}
						// Append the node
						Node["#Key#.XmlAttributes"][AttribI]=Attribs;
					}
				} else {
					if (StructKeyExists(Node,"#Key#.XmlAttributes")) {
						// If no attribs but preveious attribs set, define it as null
						Node["#Key#.XmlAttributes"][AttribI]=JavaCast("null", "");
					}
				}
			}
		}
	}
	
	return Node;
}



function GetKeyName(required string Name, required string NsPrefix, required string RemoveNsPrefix=false) {
	writeoutput("Get Key Name [#Arguments.Name#][#Arguments.NsPrefix#][#Arguments.RemoveNsPrefix#]");
	if (Arguments.RemoveNSPrefix EQ 0 OR ListFirst(Arguments.Name,":") NEQ Arguments.NsPrefix) return Arguments.Name;
	return ListRest(Arguments.Name,":");
}
</cfscript>
