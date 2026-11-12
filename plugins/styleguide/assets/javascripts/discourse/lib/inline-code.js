import { trustHTML } from "@ember/template";
import { escapeExpression } from "discourse/lib/utilities";

/**
 * Renders backticked spans in a translated string as inline code.
 *
 * Backticks rather than markup in the YAML: a translator can move them without understanding
 * HTML, and escaping stays here rather than being trusted to every string.
 *
 * Split first, then escape each piece. Escaping first and looking for backticks afterwards
 * cannot work — `escape` turns a backtick into an entity, so the pattern being searched for has
 * already been removed by the time it is searched for. Splitting on the raw string keeps the
 * two steps independent of each other's output.
 *
 * @param {string} text - a translated string, optionally containing `backticked` identifiers.
 * @returns {SafeString} the escaped text with backticked spans wrapped in `code`.
 */
export default function inlineCode(text) {
  const parts = String(text ?? "").split("`");

  // An even part count means an odd number of backticks, so the marks are unbalanced. Pairing
  // anyway would code-format the whole tail after the stray one; rendering the string as plain
  // prose keeps a typo in a translation to one visible backtick rather than a mangled sentence.
  if (parts.length % 2 === 0) {
    return trustHTML(escapeExpression(parts.join("`")));
  }

  return trustHTML(
    parts
      .map((part, index) =>
        // Odd indices sat between a pair of backticks.
        index % 2
          ? `<code>${escapeExpression(part)}</code>`
          : escapeExpression(part)
      )
      .join("")
  );
}
