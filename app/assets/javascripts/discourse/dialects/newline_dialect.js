/**
  Support for the newline behavior in markdown that most expect.

  @event parseNode
  @namespace Discourse.Dialect
**/
Discourse.Dialect.on("parseNode", function(event) {
  var node = event.node,
      opts = event.dialect.options,
      insideCounts = event.insideCounts,
      linebreaks = opts.traditional_markdown_linebreaks || Discourse.SiteSettings.traditional_markdown_linebreaks;

  if (!linebreaks) {
    // We don't add line breaks inside a pre
    if (insideCounts.pre > 0) { return; }

    if (node.length > 1) {
      for (var j=1; j<node.length; j++) {
        var textContent = node[j];

        if (typeof textContent === "string") {

          if (textContent === "\n") {
            node[j] = ['br'];
          } else {
            var split = textContent.split(/\n+/);
            if (split.length) {
              var spliceInstructions = [j, 1];
              for (var i=0; i<split.length; i++) {
                if (split[i].length > 0) {
                  spliceInstructions.push(split[i]);
                  if (i !== split.length-1) { spliceInstructions.push(['br']); }
                }
              }
              node.splice.apply(node, spliceInstructions);
            }
          }
        }
      }
    }
  }
});