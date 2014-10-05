/**
  Support for the newline behavior in markdown that most expect. Look through all text nodes
  in the tree, replace any new lines with `br`s.
**/
Discourse.Dialect.postProcessText(function (text, event) {
  var opts = event.dialect.options,
      insideCounts = event.insideCounts,
      linebreaks = opts.traditional_markdown_linebreaks || Discourse.SiteSettings.traditional_markdown_linebreaks;

  if (linebreaks || (insideCounts.pre > 0)) { return; }

  if (text === "\n") {
    // If the tag is just a new line, replace it with a `<br>`
    return [['br']];
  } else {


    // If the text node contains new lines, perhaps with text between them, insert the
    // `<br>` tags.
    var split = text.split(/\n+/);
    if (split.length) {
      var replacement = [];
      for (var i=0; i<split.length; i++) {
        if (split[i].length > 0) { replacement.push(split[i]); }
        if (i !== split.length-1) { replacement.push(['br']); }
      }

      return replacement;
    }
  }

});
