function escapeRegexp(text) {
  return text.replace(/[-/\\^$*+?.()|[\]{}]/g, '\\$&');
}

export function censor(text, censoredWords, censoredPattern) {
  let patterns = [],
      originalText = text;

  if (censoredWords && censoredWords.length) {
    patterns = censoredWords.split("|").map(t => `(${escapeRegexp(t)})`);
  }

  if (censoredPattern && censoredPattern.length > 0) {
    patterns.push("(" + censoredPattern + ")");
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
          text = text.replace(new RegExp(`(\\b${escapeRegexp(m[0])}\\b)(?![^\\(]*\\))`, "ig"), replacement);
          m = censorRegexp.exec(text);
        }
      }
    } catch(e) {
      return originalText;
    }
  }

  return text;
}
