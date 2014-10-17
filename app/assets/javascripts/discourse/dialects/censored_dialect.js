var censorRegexp;

Discourse.Dialect.addPreProcessor(function(text) {
  var censored = Discourse.SiteSettings.censored_words;
  if (censored && censored.length) {
    if (!censorRegexp) {
      var split = censored.split("|");
      if (split && split.length) {
        censorRegexp = new RegExp("\\b(?:" + split.map(function (t) { return "(" + t.replace(/[-/\\^$*+?.()|[\]{}]/g, '\\$&') + ")"; }).join("|") + ")\\b", "ig");
      }
    }

    if (censorRegexp) {
      var m = censorRegexp.exec(text);
      while (m && m[0]) {
        var replacement = new Array(m[0].length+1).join('&#9632;');
        text = text.replace(new RegExp("\\b" + m[0] + "\\b", "ig"), replacement);
        m = censorRegexp.exec(text);
      }

    }
  }
  return text;
});
