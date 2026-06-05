<cfscript>
// Return current time
public function TS() {
	return TimeFormat(Now(),"HH:mm:ss");
}

// Replaces repeating characters of "Char" with a single instance
public function ReplaceRepeats(required string VarValue, required string Char) {
	var Out=Arguments.VarValue;
	var NotDone=Find(Arguments.Char & Arguments.Char, Out);
	while (NOTDone) {
		Out=Replace(Out,Arguments.Char & Arguments.Char,Arguments.Char,"All");
		NotDone=Find(Arguments.Char & Arguments.Char, Out);
	}
	return Out;
}

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

	// First pass: count date folders (folders with DTSX files directly in them)
	var DateFolderCount=0;
	var SingleDateFolderPath="";
	
	for (DirIdx=1; DirIdx LTE Dir.RecordCount; DirIdx++) {
		if (Dir.Type[DirIdx] EQ "Dir") {
			DTSXCheck=DirectoryList(path=Dir.Directory[DirIdx] & "/" & Dir.Name[DirIdx], listinfo="name", Type="File", Filter="*.dtsx");
			if (ArrayLen(DTSXCheck) GT 0) {
				DateFolderCount=DateFolderCount + 1;
				SingleDateFolderPath=Dir.Directory[DirIdx] & "/" & Dir.Name[DirIdx];
			}
		}
	}

	// If there's only one date folder, skip the folder node and return its children directly
	if (DateFolderCount EQ 1) {
		FancyTree=BuildPackageTree(SingleDateFolderPath);
	} else {
		// Loop over directory - normal behavior when multiple date folders or no date folders
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
	}

	return FancyTree;
}

// Converts a DTSX XML node into a JSON-friendly struct while preserving nested sections
public struct function ParseDTSXNode(required xml DTSX) {
	var Node=StructNew();
	var ChildIdx=0;

	Node.Name=Arguments.DTSX.XmlName;
	Node.Attributes=Arguments.DTSX.XmlAttributes;
	Node.Text=Trim(Replace(Replace(Arguments.DTSX.XmlText,"\n","","All"),"\t","","All"));
	Node.Comment=Arguments.DTSX.XmlComment;
	Node.Children=ArrayNew(1);

	for (ChildIdx=1; ChildIdx LTE ArrayLen(Arguments.DTSX.XmlChildren); ChildIdx++) {
		Node.Children[ChildIdx]=ParseDTSXNode(Arguments.DTSX.XmlChildren[ChildIdx]);
	}

	return Node;
}

public any function ParseDTSXNodeCollection(required any DTSXNodes) {
	var Nodes=Arguments.DTSXNodes;
	var i=0;

	if (IsArray(Nodes)) {
		for (i=1; i LTE ArrayLen(Nodes); i++) {
			Nodes[i]=ParseDTSXNode(Nodes[i]);
		}
		return Nodes;
	}

	return ParseDTSXNode(Nodes);
}

public void function AddDTSXSection(required struct Package, required string Key, required any Value) {
	var Tmp="";

	if (StructKeyExists(Arguments.Package,Arguments.Key)) {
		if (IsArray(Arguments.Package[Arguments.Key]) EQ "NO") {
			Tmp=Arguments.Package[Arguments.Key];
			Arguments.Package[Arguments.Key]=ArrayNew(1);
			Arguments.Package[Arguments.Key][1]=Tmp;
		}
		ArrayAppend(Arguments.Package[Arguments.Key],Arguments.Value);
	} else {
		Arguments.Package[Arguments.Key]=Arguments.Value;
	}
}

// Recurses through the DTSC XML and extracts information into a struct
// XML Reference: https://learn.microsoft.com/en-us/openspecs/sql_data_portability/ms-dtsx/235600e9-0c13-4b5b-a388-aa3c65aec1dd
public any function ParseDTSX(required xml DTSX) {
	var Node=""; // Placeholder
	var Key=""; // Used for looping over structs
	var Config=""; // Used for remapping XML to Struct
	var Child=""; // Placeholder
	var Child2=""; // Placeholder
	var ChildIdx=0; // Loop variables
	var ObjectData="";
	var Tmp="";
	var i=0;
	var x=0;
	var y=0;
	var z=0;
	var c=0;

	var Package=StructNew();
	// If at the root, dive into it
	if (structKeyExists(Arguments.DTSX,"XmlRoot")) return ParseDTSX(Arguments.DTSX.XmlRoot);

	// Recurse for executables
	if (Arguments.DTSX.XmlName EQ "DTS:Executables") {
		// All of the children here are the steps to execute, recurse into them
		Package=ArrayNew(1);
		for (ChildIdx=1; ChildIdx LTE ArrayLen(Arguments.DTSX.XmlChildren); ChildIdx++) {
			Package[ChildIdx]=ParseDTSX(Arguments.DTSX.XmlChildren[ChildIdx]);
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
					Package.Executables=ParseDTSX(Arguments.DTSX.XmlChildren[ChildIdx]);

				} else if (Arguments.DTSX.XmlChildren[ChildIdx].XmlName EQ "DTS:PrecedenceConstraints") {
					Package.Relationships=ParseDTSX(Arguments.DTSX.XmlChildren[ChildIdx]);

				} else if (Arguments.DTSX.XmlChildren[ChildIdx].XmlName EQ "DTS:Property" AND StructKeyExists(Arguments.DTSX.XmlChildren[ChildIdx].XmlAttributes,"DTS:Name")) {
					Package[Arguments.DTSX.XmlChildren[ChildIdx].XmlAttributes["DTS:Name"]]=Arguments.DTSX.XmlChildren[ChildIdx].XmlText;

				} else if (ListFindNoCase("DTS:ObjectData,DTS:ConnectionManagers,DTS:Configurations,DTS:LogProviders,DTS:Variables,DTS:LoggingOptions,DTS:DesignTimeProperties,DTS:EventHandlers,DTS:PackageVariables,DTS:ForEachEnumerator,DTS:ForEachVariableMappings,DTS:PropertyExpression,DTS:Property",Arguments.DTSX.XmlChildren[ChildIdx].XMLName)) {
					AddDTSXSection(Package,Arguments.DTSX.XmlChildren[ChildIdx].XMLName,Arguments.DTSX.XmlChildren[ChildIdx]);
				}
			}
		}
	}

	// Parse out Package structures
	if (IsStruct(Package)) {
		// Remove unneeded namespace attributes
		for (Key in "xmlns:DTS") {
			if (StructKeyExists(Package,Key)) StructDelete(Package,Key);
		}

		if (StructKeyExists(Package,"DTS:ObjectData")) {
			// Convert to array
			if (IsArray(Package["DTS:ObjectData"]) EQ "NO") {
				Tmp=Package["DTS:ObjectData"];
				Package["DTS:ObjectData"]=ArrayNew(1);
				Package["DTS:ObjectData"][1]=Tmp;
			}

			ObjectData=ArrayNew(1);
			for (i=1; i LTE ArrayLen(Package["DTS:ObjectData"]); i++) {
				Child=Package["DTS:ObjectData"][i];
				ObjectData[i]=StructNew();
				for (Key in StructKeyList(Child.XmlAttributes)) {
					ObjectData[i][ListRest(Key,":")]=Child.XmlAttributes[Key];
				}
				ObjectData[i].Value=Trim(Replace(Replace(Child.XmlText,"\n","","All"),"\t","","All"));
				ObjectData[i].Comment=Child.XmlComment;
				ObjectData[i].Tasks=ArrayNew(1);
				for (x=1; x LTE ArrayLen(Child.XmlChildren); x++) {
					ObjectData[i].Tasks[x]=StructNew();
					ObjectData[i].Tasks[x].Name=Child.XmlChildren[x].XmlName;
					ObjectData[i].Tasks[x].Attributes=Child.XmlChildren[x].XmlAttributes;
					ObjectData[i].Tasks[x].Text=Trim(Replace(Replace(Child.XmlChildren[x].XmlText,"\n","","All"),"\t","","All"));
					ObjectData[i].Tasks[x].Comment=Child.XmlChildren[x].XmlComment;
					ObjectData[i].Tasks[x].Children=ArrayNew(1);
					for (z=1; z LTE ArrayLen(Child.XmlChildren[x].XmlChildren); z++) {
						ObjectData[i].Tasks[x].Children[z]=ParseDTSXNode(Child.XmlChildren[x].XmlChildren[z]);
					}
				}
			}
			Package["DTS:ObjectData"]=ObjectData;
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

		if (StructKeyExists(Package,"DTS:PackageVariables")) {
			Package["DTS:PackageVariables"]=ParseDTSXNodeCollection(Package["DTS:PackageVariables"]);
		}

		if (StructKeyExists(Package,"DTS:EventHandlers")) {
			Package["DTS:EventHandlers"]=ParseDTSXNodeCollection(Package["DTS:EventHandlers"]);
		}

		if (StructKeyExists(Package,"DTS:ForEachEnumerator")) {
			Package["DTS:ForEachEnumerator"]=ParseDTSXNodeCollection(Package["DTS:ForEachEnumerator"]);
		}

		if (StructKeyExists(Package,"DTS:ForEachVariableMappings")) {
			Package["DTS:ForEachVariableMappings"]=ParseDTSXNodeCollection(Package["DTS:ForEachVariableMappings"]);
		}

		if (StructKeyExists(Package,"DTS:PropertyExpression")) {
			Package["DTS:PropertyExpression"]=ParseDTSXNodeCollection(Package["DTS:PropertyExpression"]);
		}

		if (StructKeyExists(Package,"DTS:Property")) {
			Package["DTS:Property"]=ParseDTSXNodeCollection(Package["DTS:Property"]);
		}

		if (StructKeyExists(Package,"DTS:DesignTimeProperties")) {
			Package["DTS:DesignTimeProperties"]=ParseDTSXNodeCollection(Package["DTS:DesignTimeProperties"]);
		}

		if (StructKeyExists(Package,"DTS:LogProviders")) {
			Package["DTS:LogProviders"]=ParseDTSXNodeCollection(Package["DTS:LogProviders"]);
		}

		if (StructKeyExists(Package,"DTS:LoggingOptions")) {
			Package["DTS:LoggingOptions"]=ParseDTSXNodeCollection(Package["DTS:LoggingOptions"]);
		}

	}

	return Package;
}

public string function BuildNodeList(required struct Package) {
	var i=0;
	var NodeList="";

	// Render nodes
	for (i=1; i LTE ArrayLen(Package.Executables); i++) {
		NodeList=ListAppend(NodeList,"Node_" & REReplaceNoCase(Package.Executables[i]["DTS:refId"],"[^A-Z0-9]","","All") & "~" & Package.Executables[i]["DTS:refId"],"|");
	}
	return NodeList;

}

// Takes the output from ParseDTSX and builds a Mermaid string
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

/**
// From https://cflib.org/udf/formatJSON with correction from "Rory", and corrections for comma, embedded quote handling, fjson size limit by john Bartlett
* Formats a JSON string with indents &amp; new lines.
* v1.0 by Ben Koshy
*
* @param str      JSON string (Required)
* @return Returns a string of indent-formated JSON
* @author Ben Koshy (cf@animex.com)
* @version 0, September 16, 2012
*/
// formatJSON() :: formats and indents JSON string
// based on blog post @ http://ketanjetty.com/coldfusion/javascript/format-json/
// modified for CFScript By Ben Koshy @animexcom
// usage: result = formatJSON('STRING TO BE FORMATTED') OR result = formatJSON(StringVariableToFormat);

public string function formatJSON(instr) {
	var str=arguments.instr;
	var char=""; // Current char being processed
	var fjson = ''; // Output hold variables
	var fjson2 = '';
	var pos = 0;
	var i=0;
	var j=0;
	var k=0;
	var strLen = 0;
	var indentStr = chr(9); // Adjust Indent Token If you Like
	var newLine = chr(10); // Adjust New Line Token If you Like <BR>
	var InQuote=0;
	var QuoteScan="";

	if (IsJSON(str) EQ "NO") return "Not a JSON object";

	strLen = len(str);

	for (i=1; i<=strLen; i++) {
		char = mid(str,i,1);
		if (char EQ Chr(34) AND mid(str,i-1,1) NEQ "\") {
			// Flag if inside a quote or not
			InQuote = 1 - InQuote;
		}

		if (char == '}' || char == ']') {
			if (InQuote EQ 0) {
				fjson &= newLine;
				pos = pos - 1;

				for (j=1; j<=pos; j++) {
					fjson &= indentStr;
				}
			}
		}

		fjson &= char;

		if (ListFind(",|{|[",char,"|") AND InQuote EQ 0) {
			fjson &= newLine;

			if (char == '{' || char == '[') {
				pos = pos + 1;
			}

			for (k=1; k<=pos; k++) {
				fjson &= indentStr;
			}
		}

		// If the string exceeds 10K, append to fjson2 and clear fjson to avoid the exponential delay in appending to a large string in java
		if (Len(fjson) GT 10240) {
			fjson2=fjson2 & fjson;
			fjson="";
		}
	}

	return fjson2 & fjson;
}


public function StructToJSON(required any obj, numeric index=0) {
	var JSON="";
	var Keys="";
	var i=0;

	if (Arguments.index EQ 0 AND IsStruct(Arguments.obj) EQ "no") return; // Do not process if initial object isn't a struct

	if (IsArray(Arguments.Obj)) {
		if (Arguments.Index) JSON &= RepeatString(Chr(9),Arguments.Index);
		JSON = JSON & "[" & Chr(10);
		for (i=1; i LTE ArrayLen(Arguments.Obj); i++) {
			JSON = JSON & StructToJSON(Arguments.Obj[i], Arguments.Index + 1);
			if (i LT ArrayLen(Arguments.Obj)) JSON = JSON & ",";
			JSON = JSON & Chr(10);
		}
		if (Arguments.Index) JSON &= RepeatString(Chr(9),Arguments.Index);
		JSON = JSON & "]";
	}
	else if (IsStruct(Arguments.Obj)) {
		if (Arguments.Index) JSON &= RepeatString(Chr(9),Arguments.Index);
		JSON = JSON & "{" & Chr(10);
		Keys=StructKeyList(Arguments.Obj);
		for (i=1; i LTE StructCount(Arguments.Obj); i++) {
			JSON = JSON & Chr(9) & "\"" & Keys[i] & "\": " & StructToJSON(Arguments.Obj[Keys[i]], Arguments.Index + 1);
			if (i LT StructCount(Arguments.Obj)) JSON = JSON & ",";
			JSON = JSON & Chr(10);
		}
		if (Arguments.Index) JSON &= RepeatString(Chr(9),Arguments.Index);
		JSON = JSON & "}";
	}
	else if (IsNumeric(Arguments.Obj)) {
		JSON = JSON & Arguments.Obj;
	}
	else if (IsBoolean(Arguments.Obj)) {
		JSON = JSON & LCase(Arguments.Obj);
	}
	else if (IsNull(Arguments.Obj)) {
		JSON = JSON & "null";
	}
	else {
		// Escape quotes and backslashes in strings
		//var Str=Replace(Replace(Arguments.Obj,"\","\\\\","All"),"\","\\","All");
		JSON = JSON & "\"" & Str & "\"";
	}
}


</cfscript>
