export function censor(text, censoredWords, censoredPattern) {
  let patterns = [],
      originalText = text;

  if (censoredWords && censoredWords.length) {
    patterns = censoredWords.split("|").map(t => { return "(" + t.replace(/[-/\\^$*+?.()|[\]{}]/g, '\\$&') + ")"; });
  }

  if (censoredPattern && censoredPattern.length > 0) {
    try {
      new RegExp(censoredPattern); // exception if invalid
      patterns.push("(" + censoredPattern + ")");
    } catch(e) {}
  }

  if (patterns.length) {
    let censorRegexp;

    try {
      censorRegexp = new RegExp("(\\b(?:" + patterns.join("|") + ")\\b)(?![^\\(]*\\))", "ig");

      if (censorRegexp) {
        let m = censorRegexp.exec(text);

        while (m && m[0]) {
          if (m[0].length > originalText.length) { return originalText; } // regex is dangerous
          const replacement = new Array(m[0].length+1).join('&#9632;');
          text = text.replace(new RegExp("(\\b" + m[0] + "\\b)(?![^\\(]*\\))", "ig"), replacement);
          m = censorRegexp.exec(text);
        }
      }
    } catch(e) {
      return originalText;
    }
  }

  return text;
}
