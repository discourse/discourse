/** A link the markdown engine found in a piece of text. */
export interface LinkMatch {
  /** Where the link starts in the text. */
  index: number;

  /** Where the link ends in the text. */
  lastIndex: number;

  /** The link as written in the text. */
  raw: string;

  /** The normalized URL, with a protocol added when the text omitted one. */
  url: string;
}

/**
 * Finds links in plain text the way the markdown engine's linkifier does, so
 * the composer detects the same links the cooked post will render.
 */
export interface LinkMatcher {
  /** Whether the text contains a link. */
  test(text: string): boolean;

  /** Every link in the text, or `null` when there is none. */
  match(text: string): LinkMatch[] | null;

  /** The link at the very start of the text, or `null` when there is none. */
  matchAtStart(text: string): LinkMatch | null;
}
