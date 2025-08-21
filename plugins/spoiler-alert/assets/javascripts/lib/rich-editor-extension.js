import { i18n } from "discourse-i18n";

const SPOILER_NODES = ["inline_spoiler", "spoiler"];

/** @type {RichEditorExtension} */
const extension = {
  nodeSpec: {
    spoiler: {
      attrs: { blurred: { default: true } },
      group: "block",
      content: "block+",
      parseDOM: [{ tag: "div.spoiled" }],
      toDOM: () => ["div", { class: "spoiled" }, 0],
    },
    inline_spoiler: {
      attrs: { blurred: { default: true } },
      group: "inline",
      inline: true,
      content: "inline*",
      parseDOM: [{ tag: "span.spoiled" }],
      toDOM: () => ["span", { class: "spoiled" }, 0],
    },
  },
  parse: {
    bbcode_spoiler: { block: "inline_spoiler" },
    wrap_bbcode(state, token) {
      if (token.nesting === 1 && token.attrGet("class") === "spoiler") {
        state.openNode(state.schema.nodes.spoiler);
        return true;
      } else if (token.nesting === -1 && state.top().type.name === "spoiler") {
        state.closeNode();
        return true;
      }
    },
  },
  serializeNode: {
    spoiler(state, node) {
      state.write("[spoiler]\n");
      state.renderContent(node);
      state.write("[/spoiler]\n\n");
    },
    inline_spoiler(state, node) {
      state.write("[spoiler]");
      state.renderInline(node);
      state.write("[/spoiler]");
    },
  },
  inputRules: ({ pmState: { TextSelection } }) => ({
    match: /\[spoiler\]$/,
    handler: (state, match, start, end) => {
      const { schema } = state;
      const textNode = schema.text(i18n("composer.spoiler_text"));

      const atStart = state.doc.resolve(start).parentOffset === 0;

      const tr = state.tr;

      if (atStart) {
        tr.replaceWith(
          start - 1,
          end,
          schema.nodes.spoiler.createAndFill(
            null,
            schema.nodes.paragraph.createAndFill(null, textNode)
          )
        );
      } else {
        tr.replaceWith(
          start,
          end,
          schema.nodes.inline_spoiler.createAndFill(null, textNode)
        );
      }

      return tr.setSelection(
        TextSelection.create(tr.doc, start + 1, start + 1 + textNode.nodeSize)
      );
    },
  }),
  state: ({ utils, schema }, state) => ({
    inSpoiler: SPOILER_NODES.some((nodeType) =>
      utils.inNode(state, schema.nodes[nodeType])
    ),
  }),
  commands: ({ schema, utils, pmState: { TextSelection }, pmCommands }) => ({
    toggleSpoiler() {
      return (state, dispatch, view) => {
        const { selection } = state;
        const { empty, $from, $to } = selection;

        const inSpoiler = SPOILER_NODES.some((nodeType) =>
          utils.inNode(state, schema.nodes[nodeType])
        );

        if (inSpoiler) {
          // Find the nearest spoiler node and unwrap it by replacing with its contents
          for (let depth = $from.depth; depth > 0; depth--) {
            const node = $from.node(depth);
            if (SPOILER_NODES.includes(node.type.name)) {
              const spoilerStart = $from.before(depth);
              const spoilerEnd = spoilerStart + node.nodeSize;

              // Extract content and replace spoiler with it
              const tr = state.tr.replaceWith(
                spoilerStart,
                spoilerEnd,
                node.content
              );

              dispatch?.(tr);

              return true;
            }
          }

          return false;
        }

        // For empty selection, create spoiler with placeholder text
        if (empty) {
          const textNode = schema.text(i18n("composer.spoiler_text"));
          const isBlockSpoiler = view.endOfTextblock("backward");
          const spoilerNode = isBlockSpoiler
            ? schema.nodes.spoiler.createAndFill(
                null,
                schema.nodes.paragraph.createAndFill(null, textNode)
              )
            : schema.nodes.inline_spoiler.createAndFill(null, textNode);

          const tr = state.tr.replaceSelectionWith(spoilerNode);
          tr.setSelection(
            TextSelection.create(
              tr.doc,
              $from.pos + 1,
              $from.pos + 1 + textNode.nodeSize
            )
          );

          dispatch?.(tr);

          return true;
        }

        const isBlockNodeSelection =
          $from.parent === $to.parent &&
          $from.parentOffset === 0 &&
          $to.parentOffset === $from.parent.content.size &&
          $from.parent.isBlock &&
          $from.depth > 0;
        if (isBlockNodeSelection) {
          return pmCommands.wrapIn(schema.nodes.spoiler)(state, dispatch);
        }

        const slice = selection.content();
        const isInlineSelection = slice.openStart > 0 || slice.openEnd > 0;

        if (isInlineSelection) {
          const content = [];
          slice.content.forEach((node) =>
            node.isBlock
              ? node.content.forEach((child) => content.push(child))
              : content.push(node)
          );
          const spoilerNode = schema.nodes.inline_spoiler.createAndFill(
            null,
            content
          );

          const tr = state.tr.replaceWith($from.pos, $to.pos, spoilerNode);
          tr.setSelection(
            TextSelection.create(
              tr.doc,
              $from.pos + 1,
              $from.pos + 1 + spoilerNode.content.size
            )
          );

          dispatch?.(tr);

          return true;
        } else {
          return pmCommands.wrapIn(schema.nodes.spoiler)(state, (tr) => {
            tr.setSelection(
              TextSelection.create(tr.doc, $from.pos + 2, $to.pos)
            );

            dispatch?.(tr);
          });
        }
      };
    },
  }),
  plugins({ pmState: { Plugin }, pmView: { Decoration, DecorationSet } }) {
    return new Plugin({
      props: {
        decorations(state) {
          return this.getState(state);
        },
      },
      state: {
        init(config, state) {
          // Initially blur all spoilers
          const decorations = [];

          state.doc.descendants((node, pos) => {
            if (SPOILER_NODES.includes(node.type.name)) {
              decorations.push(
                Decoration.node(pos, pos + node.nodeSize, {
                  class: "spoiler-blurred",
                })
              );
            }
            return true;
          });

          return DecorationSet.create(state.doc, decorations);
        },
        apply(tr, set, oldState, newState) {
          // If there's a meta update, use it (for manual updates)
          if (tr.getMeta(this)) {
            return tr.getMeta(this);
          }

          // Map existing decorations through the transaction
          set = set.map(tr.mapping, tr.doc);

          // Only recalculate if selection changed (which includes document changes that affect selection)
          if (tr.selectionSet || tr.docChanged) {
            const decorations = [];
            const { selection } = newState;

            newState.doc.descendants((node, pos) => {
              if (SPOILER_NODES.includes(node.type.name)) {
                const nodeStart = pos;
                const nodeEnd = pos + node.nodeSize;

                const cursorInSpoiler =
                  (selection.from > nodeStart && selection.from < nodeEnd) ||
                  (selection.to > nodeStart && selection.to < nodeEnd) ||
                  (selection.from <= nodeStart && selection.to >= nodeEnd);

                if (!cursorInSpoiler) {
                  decorations.push(
                    Decoration.node(nodeStart, nodeEnd, {
                      class: "spoiler-blurred",
                    })
                  );
                }
              }
              return true;
            });

            return DecorationSet.create(newState.doc, decorations);
          }

          return set;
        },
      },
    });
  },
};

export default extension;
