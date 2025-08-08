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
  keymap({ pmState: { Selection } }) {
    return {
      Enter: (state, dispatch) => {
        const { $from } = state.selection;

        if ($from.node().type.name === "inline_spoiler") {
          if (dispatch) {
            const tr = state.tr;

            // Find the spoiler node
            let spoilerDepth = null;
            for (let depth = $from.depth; depth > 0; depth--) {
              if ($from.node(depth).type.name === "inline_spoiler") {
                spoilerDepth = depth;
                break;
              }
            }

            if (spoilerDepth !== null) {
              const spoilerPos = $from.before(spoilerDepth);
              const spoilerEnd = $from.after(spoilerDepth);
              const cursorPos = $from.pos;

              // Split spoiler content at cursor
              const beforeCursor = tr.doc.slice(
                spoilerPos + 1,
                cursorPos
              ).content;
              const afterCursor = tr.doc.slice(
                cursorPos,
                spoilerEnd - 1
              ).content;

              // Create new spoiler with content before cursor
              const spoilerNode = state.schema.nodes.inline_spoiler.create(
                null,
                beforeCursor
              );

              // Create new paragraph with content after cursor (not in spoiler)
              const paragraphNode = state.schema.nodes.paragraph.create(
                null,
                afterCursor
              );

              // Replace the original spoiler with spoiler + paragraph
              tr.replaceWith(spoilerPos, spoilerEnd + 1, [
                spoilerNode,
                paragraphNode,
              ]);

              // Set cursor at start of new paragraph content
              const newCursorPos = spoilerPos + spoilerNode.nodeSize + 1;
              tr.setSelection(Selection.near(tr.doc.resolve(newCursorPos)));

              dispatch(tr);
            }
          }
          return true;
        }

        return false;
      },
    };
  },
  inputRules: ({ pmState: { TextSelection } }) => ({
    match: /\[spoiler\]$/,
    handler: (state, match, start, end) => {
      const { schema } = state;
      const textNode = schema.text(i18n("composer.spoiler_text"));

      let spoilerNode;
      if (start === 0) {
        // Block spoiler at start of line
        spoilerNode = schema.nodes.spoiler.createAndFill(
          null,
          schema.nodes.paragraph.createAndFill(null, textNode)
        );
      } else {
        // Inline spoiler
        spoilerNode = schema.nodes.inline_spoiler.createAndFill(null, textNode);
      }

      const tr = state.tr.replaceWith(start, end, spoilerNode);

      // Select the placeholder text for editing
      // For block spoilers, text is inside paragraph inside spoiler (depth 2)
      // For inline spoilers, text is directly inside spoiler (depth 1)
      const textStart = start === 0 ? start + 2 : start + 1;
      tr.setSelection(
        TextSelection.create(tr.doc, textStart, textStart + textNode.nodeSize)
      );

      return tr;
    },
  }),
  state: ({ utils, schema }, state) => ({
    inSpoiler:
      utils.inNode(state, schema.nodes.spoiler) ||
      utils.inNode(state, schema.nodes.inline_spoiler),
  }),
  commands: ({ schema, utils, pmState: { TextSelection } }, view) => ({
    toggleSpoiler() {
      return (state, dispatch) => {
        const { selection } = state;
        const { empty, $from, $to } = selection;

        const inSpoiler = SPOILER_NODES.some((nodeType) =>
          utils.inNode(state, schema.nodes[nodeType])
        );

        if (inSpoiler) {
          for (let depth = $from.depth; depth > 0; depth--) {
            const node = $from.node(depth);
            if (SPOILER_NODES.includes(node.type.name)) {
              const spoilerPos = $from.before(depth);
              const start = spoilerPos;
              const end = spoilerPos + node.nodeSize;

              // Extract content and replace spoiler with it
              const innerContent = state.doc.slice(start + 1, end - 1).content;
              const tr = state.tr.replaceWith(start, end, innerContent);
              dispatch(tr);
              return true;
            }
          }
          return true;
        }

        if (empty) {
          let spoilerNode;
          const textNode = schema.text(i18n("composer.spoiler_text"));
          if (view.endOfTextblock("backward")) {
            spoilerNode = schema.nodes.spoiler.createAndFill(
              null,
              schema.nodes.paragraph.createAndFill(null, textNode)
            );
          } else {
            spoilerNode = schema.nodes.inline_spoiler.createAndFill(
              null,
              textNode
            );
          }

          const tr = state.tr.replaceSelectionWith(spoilerNode);
          const insertPos = $from.pos;
          // Select the placeholder text for editing
          tr.setSelection(
            TextSelection.create(
              tr.doc,
              insertPos + 1,
              insertPos + 1 + textNode.nodeSize
            )
          );

          dispatch(tr);

          return true;
        }

        const slice = selection.content();

        // Count paragraph nodes in the slice - if more than 1, use block spoiler
        let paragraphCount = 0;
        slice.content.forEach((node) => {
          if (node.type.name === "paragraph") {
            paragraphCount++;
          }
        });

        const isInlineSelection = paragraphCount <= 1;

        let spoilerNode;
        if (isInlineSelection) {
          // For inline spoilers, preserve all inline content including formatting
          let inlineContent = [];
          slice.content.forEach((node) => {
            if (node.isBlock) {
              // Extract inline content from block nodes
              node.content.forEach((child) => {
                inlineContent.push(child);
              });
            } else {
              // Keep inline nodes as-is (text, bold, italic, etc.)
              inlineContent.push(node);
            }
          });

          spoilerNode = schema.nodes.inline_spoiler.createAndFill(
            null,
            inlineContent
          );
        } else {
          // For block spoilers, ensure content is wrapped in paragraphs
          const blockContent = [];
          slice.content.forEach((node) => {
            if (node.isBlock) {
              blockContent.push(node);
            } else if (node.isText) {
              // Wrap text nodes in paragraphs
              const para = schema.nodes.paragraph.createAndFill(null, [node]);
              if (para) {
                blockContent.push(para);
              }
            } else {
              // For other inline nodes, try to wrap in paragraph
              const para = schema.nodes.paragraph.createAndFill(null, [node]);
              if (para) {
                blockContent.push(para);
              }
            }
          });

          // Ensure we have at least one paragraph if blockContent is empty
          if (blockContent.length === 0) {
            const emptyPara = schema.nodes.paragraph.createAndFill();
            if (emptyPara) {
              blockContent.push(emptyPara);
            }
          }

          spoilerNode = schema.nodes.spoiler.createAndFill(null, blockContent);
        }

        const tr = state.tr.replaceWith($from.pos, $to.pos, spoilerNode);
        tr.setSelection(
          TextSelection.create(
            tr.doc,
            $from.pos + 1,
            $from.pos + spoilerNode.nodeSize - 1
          )
        );

        dispatch(tr);

        return true;
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
