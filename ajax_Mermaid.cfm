<cfscript>
cfparam(name="URL.Mermaid", default="");

FN=RootDir & "/" & URL.Mermaid;
FN=ListDeleteAt(FN,ListLen(FN,"."),".") & ".Mermaid";

if (Left(URL.Mermaid,9) EQ "/Exports/" AND Find("..",URL.Mermaid) EQ 0 AND FileExists("#RootDir#/#URL.Mermaid#") AND FileExists(FN)) {
	MermaidData=StripCR(FileRead(FN));
	writeoutput(MermaidData);
}
</cfscript>
