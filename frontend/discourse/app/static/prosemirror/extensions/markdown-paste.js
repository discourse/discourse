/** @type {RichEditorExtension} */
const extension = {
  plugins({
    pmState: { Plugin },
    pmModel: { Fragment, Slice },
    utils: { convertFromMarkdown },
  }) {
    function splitNonEmptyLines(text) {
      return text.split(/\r?\n/).filter((line) => line.trim().length > 0);
    }

    function buildListSlice(schema, listType, lines) {
      const listItems = lines.map((line) =>
        schema.nodes.list_item.create(null, [
          schema.nodes.paragraph.create(null, schema.text(line)),
        ])
      );
      const listNode = schema.nodes[listType].create(null, listItems);

      return Slice.maxOpen(Fragment.from(listNode));
    }

    function getEmptyListPasteContext(view) {
      const { selection, schema } = view.state;

      if (!selection.empty) {
        return null;
      }

      const { $from } = selection;

      for (let depth = $from.depth; depth > 1; depth--) {
        const node = $from.node(depth);

        if (node.type !== schema.nodes.list_item) {
          continue;
        }

        const parentList = $from.node(depth - 1);
        const isSupportedList =
          parentList.type === schema.nodes.bullet_list ||
          parentList.type === schema.nodes.ordered_list;
        const isEmptyParagraph =
          node.childCount === 1 &&
          node.firstChild?.type === schema.nodes.paragraph &&
          node.firstChild.content.size === 0;

        if (isSupportedList && isEmptyParagraph && $from.parentOffset === 0) {
          return { listType: parentList.type.name };
        }

        return null;
      }

      return null;
    }

    return new Plugin({
      props: {
        clipboardTextParser(text, $context, plain, view) {
          const listContext = view && getEmptyListPasteContext(view);

          if (listContext) {
            const lines = splitNonEmptyLines(text);

            if (lines.length > 1) {
              return buildListSlice(
                view.state.schema,
                listContext.listType,
                lines
              );
            }
          }

          const doc = convertFromMarkdown(text);
          return Slice.maxOpen(Fragment.from(doc.content));
        },
      },
    });
  },
};

export default extension;
