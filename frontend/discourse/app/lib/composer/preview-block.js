/**
 * Builds the source of a preview block, trimmed of the padding cooked markup
 * puts around it.
 *
 * @param {import("prosemirror-model").Schema} schema
 * @param {string} source
 * @param {string} [params] language the source is highlighted as
 * @returns {import("prosemirror-model").Node} a `preview_source` node
 */
export function previewSourceNode(schema, source, params = "") {
  const trimmed = source.trim();

  return schema.nodes.preview_source.create(
    { params },
    trimmed ? schema.text(trimmed) : null
  );
}

/**
 * Puts the caret in the source of a preview block a transaction just inserted.
 *
 * Fitting the block in can move it past `from`, so the first `preview_source`
 * at or after it is the one that was just created.
 *
 * @param {import("prosemirror-state").Transaction} tr
 * @param {typeof import("prosemirror-state").TextSelection} TextSelection
 * @param {number} from position the block was written to
 * @returns {import("prosemirror-state").Transaction} the same transaction
 */
export function selectPreviewSource(tr, TextSelection, from) {
  let pos;

  tr.doc.nodesBetween(from, tr.doc.content.size, (node, nodePos) => {
    if (pos !== undefined) {
      return false;
    }

    if (node.type.name === "preview_source") {
      pos = nodePos + 1;
      return false;
    }
  });

  return pos === undefined
    ? tr
    : tr.setSelection(TextSelection.create(tr.doc, pos)).scrollIntoView();
}
