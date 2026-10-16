import { trustHTML } from "@ember/template";
import { escapeExpression } from "discourse/lib/utilities";

/**
 * Renders backticked spans in a translated string as inline code.
 *
 * The prose on this page is dense with argument and block names, and an identifier set as
 * running text is both harder to scan and occasionally ambiguous — "never mutates @value" reads
 * oddly mid-sentence. Marking them up in the translation keeps the sentence whole, which
 * splitting it across keys would not.
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
  return trustHTML(
    String(text ?? "")
      .split("`")
      .map((part, index) =>
        // Odd indices sat between a pair of backticks.
        index % 2
          ? `<code>${escapeExpression(part)}</code>`
          : escapeExpression(part)
      )
      .join("")
  );
}
