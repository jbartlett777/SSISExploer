<cfscript>
cfparam(name="URL.Mermaid", default="");

FN=RootDir & URL.Mermaid;
BaseFN=ListDeleteAt(FN,ListLen(FN,"."),".");
MermaidFN=BaseFN & ".mermaid";
NodeFN=BaseFN & ".nodes";

if (Left(URL.Mermaid,9) EQ "/Exports/" AND Find("..",URL.Mermaid) EQ 0 AND FileExists("#RootDir#/#URL.Mermaid#") AND FileExists(MermaidFN)) {
	MermaidData=StripCR(FileRead(MermaidFN));
	NodeList=FileRead(NodeFN);
	// Remove info after ~ in list
	NodeList=REReplace(NodeList,"~.*?(\||$)","|","All");
	writeoutput(NodeList & "~" & MermaidData);
}
</cfscript>
