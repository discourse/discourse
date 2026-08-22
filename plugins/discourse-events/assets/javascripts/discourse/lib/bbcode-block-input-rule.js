/**
 * Converts a typed opening tag into its node, so `[calendar]` becomes a
 * calendar the moment it is closed.
 *
 * @param {string} tag bbcode tag name
 * @param {string} nodeName schema node the markdown is expected to produce
 * @param {RegExp} [match] overrides the default "tag with optional attributes"
 * @returns {(params: PluginParams) => object} a rich editor input rule
 */
export default function bbcodeBlockInputRule(tag, nodeName, match) {
  return ({ utils: { convertFromMarkdown } }) => ({
    match: match ?? new RegExp(`^\\[${tag}(\\s[^\\]]*)?]$`),
    handler: (state, matched, start, end) => {
      const attrs = (matched[1] ?? "").trim();
      const markdown = `[${tag}${attrs ? ` ${attrs}` : ""}]\n[/${tag}]`;

      const doc = convertFromMarkdown(markdown);
      const node = doc.content.firstChild;

      return node?.type === state.schema.nodes[nodeName]
        ? state.tr.replaceWith(start, end, node)
        : null;
    },
  });
}
