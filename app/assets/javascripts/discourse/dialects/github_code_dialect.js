/**
  Support for github style code blocks, here you begin with three backticks and supply a language,
  The language is made into a class on the resulting `<code>` element.

  @event register
  @namespace Discourse.Dialect
**/
Discourse.Dialect.on("register", function(event) {
  var dialect = event.dialect,
      MD = event.MD;

  /**
    Support for github style code blocks

    @method githubCode
    @param {Markdown.Block} block the block to examine
    @param {Array} next the next blocks in the sequence
    @return {Array} the JsonML containing the markup or undefined if nothing changed.
    @namespace Discourse.Dialect
  **/
  dialect.block.github_code = function githubCode(block, next) {

    var m = /^`{3}([^\n]+)?\n?([\s\S]*)?/gm.exec(block);

    if (m) {
      var startPos = block.indexOf(m[0]),
          leading,
          codeContents = [],
          result = [],
          lineNumber = block.lineNumber;

      if (startPos > 0) {
        leading = block.slice(0, startPos);
        lineNumber += (leading.split("\n").length - 1);

        var para = ['p'];
        this.processInline(leading).forEach(function (l) {
          para.push(l);
        });

        result.push(para);
      }

      if (m[2]) { next.unshift(MD.mk_block(m[2], null, lineNumber + 1)); }

      lineNumber++;
      while (next.length > 0) {
        var b = next.shift(),
            blockLine = b.lineNumber,
            diff = ((typeof blockLine === "undefined") ? lineNumber : blockLine) - lineNumber;

        b = b.replace(/ {2}\n/g, "\n");
        var n = b.match(/([^`]*)```([^`]*)/m);

        for (var i=1; i<diff; i++) {
          codeContents.push("");
        }
        lineNumber = blockLine + b.split("\n").length - 1;

        if (n) {
          if (n[2]) {
            next.unshift(MD.mk_block(n[2]));
          }

          codeContents.push(n[1].replace(/\s+$/, ""));
          break;
        } else {
          codeContents.push(b);
        }
      }

      result.push(['p', ['pre', ['code', {'class': m[1] || 'lang-auto'}, codeContents.join("\n") ]]]);
      return result;
    }
  };

});

/**
  Ensure that content in a code block is fully escaped. This way it's not white listed
  and we can use HTML and Javascript examples.

  @event parseNode
  @namespace Discourse.Dialect
**/
Discourse.Dialect.on("parseNode", function(event) {
  var node = event.node;

  if (node[0] === 'code') {
    node[node.length-1] = Handlebars.Utils.escapeExpression(node[node.length-1]);
  }
});


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
