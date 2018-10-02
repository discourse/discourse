function escapeRegexp(text) {
  return text.replace(/[-/\\^$*+?.()|[\]{}]/g, "\\$&").replace(/\*/g, "S*");
}

function createCensorRegexp(patterns) {
  // prettier-ignore
  return new RegExp(
    "(\\b" +                           // A word boundary
    "(?:" + patterns.join("|") + ")" + // Followed by one of the censored words
    "(?:" +                            // Followed by one of
    "(?<!\\$)\\b" + "|" +              //  - A word boundary without a literal $ before it
    "(?<=\\$)(?!\\w)" + "))" +         //  - After dollar, and next character is not a word
    "(?![^\\(]*\\))",                  // NOT immediately followed by the beginning of a string, OR an open parenthesis
    "ig"                               // Case insensive, global match
  );
}

export function censorFn(
  censoredWords,
  replacementLetter,
  watchedWordsRegularExpressions
) {
  let patterns = [];

  replacementLetter = replacementLetter || "&#9632;";

  if (censoredWords && censoredWords.length) {
    patterns = censoredWords.split("|");
    if (!watchedWordsRegularExpressions) {
      patterns = patterns.map(t => `(${escapeRegexp(t)})`);
    }
  }

  if (patterns.length) {
    let censorRegexp;

    try {
      if (watchedWordsRegularExpressions) {
        censorRegexp = new RegExp(
          "((?:" + patterns.join("|") + "))(?![^\\(]*\\))",
          "ig"
        );
      } else {
        censorRegexp = createCensorRegexp(patterns);
        console.log(censorRegexp);
      }

      if (censorRegexp) {
        return function(text) {
          let original = text;

          try {
            let m = censorRegexp.exec(text);
            const fourCharReplacement = new Array(5).join(replacementLetter);

            while (m && m[0]) {
              if (m[0].length > original.length) {
                return original;
              } // regex is dangerous
              if (watchedWordsRegularExpressions) {
                text = text.replace(censorRegexp, fourCharReplacement);
              } else {
                const replacement = new Array(m[0].length + 1).join(
                  replacementLetter
                );
                text = text.replace(
                  createCensorRegexp([escapeRegexp(m[0])]),
                  replacement
                );
              }
              m = censorRegexp.exec(text);
            }

            return text;
          } catch (e) {
            return original;
          }
        };
      }
    } catch (e) {
      // fall through
    }
  }

  return function(t) {
    return t;
  };
}

export function censor(text, censoredWords, replacementLetter) {
  return censorFn(censoredWords, replacementLetter)(text);
}
