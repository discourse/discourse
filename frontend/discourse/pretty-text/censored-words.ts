/**
 * A censored word, as a one-entry object that maps the source of a regular
 * expression to its options. The expression captures the word in a group.
 */
export type CensoredWord = Record<string, { case_sensitive: boolean }>;

/**
 * Builds a function that censors the given words in a text.
 *
 * Each letter of a censored word is replaced with the replacement letter.
 *
 * @param regexpList - The censored words. When empty or missing, the returned
 *   function returns the text unchanged.
 * @param replacementLetter - The HTML that replaces each letter.
 * @returns A function that returns the censored text.
 */
export function censorFn(
  regexpList: CensoredWord[] | null | undefined,
  replacementLetter = "&#9632;"
): (text: string) => string {
  if (regexpList?.length) {
    const censorRegexps = regexpList.map((entry) => {
      const [regexp, options] = Object.entries(entry)[0];
      return new RegExp(regexp, options.case_sensitive ? "gu" : "gui");
    });

    return function (text: string) {
      censorRegexps.forEach((censorRegexp) => {
        text = text.replace(
          censorRegexp,
          (fullMatch, ...groupMatches: unknown[]) => {
            // The match always captures the word, so a string group is present.
            const stringMatch = groupMatches.find(
              (g) => typeof g === "string"
            ) as string;
            return fullMatch.replace(
              stringMatch,
              new Array(stringMatch.length + 1).join(replacementLetter)
            );
          }
        );
      });

      return text;
    };
  }

  return function (t: string) {
    return t;
  };
}

/**
 * Censors the given words in a text.
 *
 * @param text - The text to censor.
 * @param censoredRegexp - The censored words.
 * @param replacementLetter - The HTML that replaces each letter.
 * @returns The censored text.
 */
export function censor(
  text: string,
  censoredRegexp: CensoredWord[] | null | undefined,
  replacementLetter?: string
): string {
  return censorFn(censoredRegexp, replacementLetter)(text);
}
