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
</cfscript>