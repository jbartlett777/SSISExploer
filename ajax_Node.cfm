<cfscript>
cfparam(name="URL.Package", default="");
cfparam(name="URL.Node", default="");

FN=RootDir & URL.Package;
BaseFN=ListDeleteAt(FN,ListLen(FN,"."),".");
NodeFN=BaseFN & ".nodes";
PackageFN=BaseFN & ".json";

if (Left(URL.Package,9) EQ "/Exports/" AND Find("..",URL.Package) EQ 0 AND FileExists("#RootDir#/#URL.Package#") AND FileExists(PackageFN)) {
	NodeData=FileRead(NodeFN);
	PackageJSON=FileRead(PackageFN);
	writeoutput(PackageFN);
	JSON=DeserializeJSON(PackageJSON);
	Executable="";
	Loc=ListContains(NodeData,URL.Node,"|");
	//writeoutput("[#nodedata#]<br>[#url.node#]<br>");
	RefID=ListLast(ListGetAt(NodeData,Loc,"|"),"~");
	//writeoutput("Loc=[#Loc#]<br>URL.Node=[#URL.Node#]<br>RefID=[#RefID#]<hr>");
	// Locate Executable
	for (i=1; i LTE ArrayLen(JSON.Executables); i++) {
		if (JSON.Executables[i]["DTS:refId"] EQ RefID) {
			Executable=JSON.Executables[i];
			break;
		}
	}
	writedump(Executable,"browser","html",false,"Exec");

	//writedump(var=#JSON#);
}
</cfscript>
