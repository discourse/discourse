function escapeRegexp(text) {
  return text.replace(/[-/\\^$*+?.()|[\]{}]/g, '\\$&');
}

export function censorFn(censoredWords, censoredPattern, replacementLetter) {

  let patterns = [];

  replacementLetter = replacementLetter || "&#9632;";

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

        return function(text) {
          let original = text;

          try {
            let m = censorRegexp.exec(text);

            while (m && m[0]) {
              if (m[0].length > original.length) { return original; } // regex is dangerous
              const replacement = new Array(m[0].length+1).join(replacementLetter);
              text = text.replace(new RegExp(`(\\b${escapeRegexp(m[0])}\\b)(?![^\\(]*\\))`, "ig"), replacement);
              m = censorRegexp.exec(text);
            }

            return text;
          } catch (e) {
            return original;
          }
        };

      }
    } catch(e) {
      // fall through
    }
  }

  return function(t){ return t;};
}

export function censor(text, censoredWords, censoredPattern, replacementLetter) {
  return censorFn(censoredWords, censoredPattern, replacementLetter)(text);
}
