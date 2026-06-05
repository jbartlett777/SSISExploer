<CFSETTING requesttimeout="300">
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

<CFINCLUDE template="ImportPackages.cfm">

<cfset exported=1>
<CFIF Exported EQ 1 OR FileExists("#RootDir#/Exports/FancyTree.json") EQ "NO">
	<CFOUTPUT>#TS()# Building Package Tree...</CFOUTPUT><CFFLUSH>
	<CFSET FancyTree=BuildPackageTree("#RootDir#/Exports")>
	<CFIF ArrayLen(FancyTree) EQ 1>
		<!--- Auto expand root node if only one --->
		<CFSET FancyTree[1]["expanded"]="true">
	</CFIF>
	<CFSET FancyTreeJSON=FormatJSON(SerializeJSON(FancyTree))>
	<CFOUTPUT>Done.<br></CFOUTPUT>
	<CFFILE action="write" file="#RootDir#/Exports/FancyTree.json" output="#FancyTreeJSON#" addnewline="NO" mode="666">
</CFIF>
<CFOUTPUT>
</div>
<CFFILE action="read" file="#RootDir#/Exports/FancyTree.json" variable="FancyTreeJSON">

<script>
function bindClickToPipeDelimitedIds(input, clickHandler) {
	if (!input || typeof input !== "string") return $();

	const tokens = input.split("|").map(t => t.trim()).filter(Boolean);
	let $results = $();

	tokens.forEach(token => {
		const $matches = $(`[id*="${token}"]`);
		$matches.each(function () {
			const $el = $(this);

			// Avoid duplicate bindings if function is called multiple times
			$el.off("click.pipeHandler");

			// Attach namespaced click handler
			$el.on("click.pipeHandler", function (e) {
				if (typeof clickHandler === "function") {
					clickHandler.call(this, e, token);
				} else {
					// console.log("Clicked:", this.id, "matched token:", token);
					ShowInfo(token);
				}
			});

			// Set pointer cursor
			$el.css("cursor", "pointer");
		});

		$results = $results.add($matches);
	});

	return $results;
}

document.getElementById('Status').style.display='none';
var Code=#FancyTreeJSON#;
function ShowTree() {
	$("##tree").fancytree({
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

var Package='';
function ViewCode(Path) {
	$.ajax({
		type: 'GET',
		url: 'ajax_Mermaid.cfm?Mermaid=' + Path,
		success: function(data) {
			// Split the response into two parts
			//console.log(data);
			var parts = data.split('~');

			// Assign variables
			var NodeList = parts[0] || '';
			var MermaidChart = parts[1] || '';

			// Optional: debug
			// Pass only the MermaidChart to RenderChart
			Package=Path;
			RenderChart(MermaidChart);
			document.getElementById('info').innerHTML='';
			// Attach achors to the nodes after a short delay to allow Mermaid to do it's thing
			setTimeout(bindClickToPipeDelimitedIds,250,NodeList);
		},
		error: function(event, request, settings) {
			alert('failed [' + event + '][' + request + '][' + settings + ']');
		}
	});
}
function ShowInfo(ViewNode) {
	$.ajax({
		type: 'GET',
		url: 'ajax_Node.cfm?Package=' + Package + '&Node=' + ViewNode,
		success: function(data) {
			document.getElementById('info').innerHTML=data;
		},
		error: function(event, request, settings) {
			alert('failed [' + event + '][' + request + '][' + settings + ']\najax_node.cfm?Package='+Package+'&Node='+ViewNode);
		}
	});
}

//mermaid.initialize({ startOnLoad: true });
</script>

<style type="text/css">
html, body {
  height: 100%;
  margin: 0;
  overflow: hidden; /* prevents page-level scrolling */
}

.home-container1 {
  height: 100vh;              /* lock to viewport */
  display: flex;
  flex-direction: column;
}

.home-container2 {
  flex: 1;                    /* fill remaining height */
  display: flex;
  overflow: hidden;           /* prevent expansion */
  min-height: 0;              /* critical for flex scroll behavior */
}

/* Left column */
.home-container3 {
  width: 350px;
  display: flex;
  flex-direction: column;
  overflow-y: auto;           /* scroll only when needed */
  padding-right: 8px;
  min-height: 0;
}

/* Middle column */
.home-container4 {
  flex: 1;
  display: flex;
  flex-direction: column;
  overflow-y: auto;
  min-height: 0;
}

/* Right column */
.home-container5 {
  flex: 1;
  display: flex;
  flex-direction: column;
  overflow-y: auto;
  padding-left: 8px;
  min-height: 0;
}
</style>

<!--- Page display --->
<div id="Page" class="home-container1">
	<div id="main" class="home-container2">
		<div id="tree" class="home-container3"></div>
		<div id="chart" class="home-container4"></div>
		<div id="info" class="home-container5"></div>
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

