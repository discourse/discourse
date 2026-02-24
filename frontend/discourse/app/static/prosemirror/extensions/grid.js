import GridNodeView from "../components/grid-node-view";

const extension = {
  nodeViews: {
    grid: {
      component: GridNodeView,
      hasContent: true,
    },
  },

  nodeSpec: {
    grid: {
      content: "block+",
      group: "block",
      attrs: {
        mode: { default: "grid" },
      },
      createGapCursor: true,
      parseDOM: [
        {
          tag: "div.d-image-grid",
          getAttrs(dom) {
            return {
              mode: dom.getAttribute("data-mode") || "grid",
            };
          },
        },
        {
          tag: "div.composer-image-grid",
          getAttrs(dom) {
            return {
              mode: dom.getAttribute("data-mode") || "grid",
            };
          },
        },
      ],
      toDOM(node) {
        return [
          "div",
          {
            class: "composer-image-grid",
            "data-mode": node.attrs.mode,
          },
          0,
        ];
      },
    },
  },

  parse: {
    bbcode_open(state, token) {
      if (token.attrGet("class") === "d-image-grid") {
        state.openNode(state.schema.nodes.grid, {
          mode: token.attrGet("data-mode") || "grid",
        });
        return true;
      }
    },
    bbcode_close(state) {
      if (state.top().type.name === "grid") {
        state.closeNode();
        return true;
      }
    },
  },

  serializeNode: {
    grid: (state, node) => {
      let attrs = "";
      if (node.attrs.mode && node.attrs.mode !== "grid") {
        attrs += ` mode=${node.attrs.mode}`;
      }
      state.write(`\n[grid${attrs}]\n\n`);
      state.renderContent(node.content);
      state.write("\n[/grid]\n\n");
    },
  },

  inputRules: () => ({
    match: /^\[grid]$/,
    handler: (state, match, start, end) => {
      const grid = state.schema.nodes.grid.createAndFill();
      return state.tr.replaceWith(start - 1, end, grid);
    },
  }),

  plugins({ pmState: { Plugin } }) {
    return new Plugin({
      appendTransaction(transactions, oldState, newState) {
        if (!transactions.some((tr) => tr.docChanged)) {
          return null;
        }

        const tr = newState.tr;
        let modified = false;

        const gridNodes = [];
        newState.doc.descendants((node, pos) => {
          if (node.type.name === "grid") {
            gridNodes.push({ node, pos });
          }
        });

        gridNodes.reverse().forEach(({ node, pos }) => {
          if (node.childCount === 0) {
            tr.delete(pos, pos + node.nodeSize);
            modified = true;
            return;
          }

          const changes = [];
          let currentPos = pos + 1;

          node.content.forEach((child) => {
            if (child.type.name === "paragraph") {
              if (child.content.size === 0) {
                if (node.childCount > 1) {
                  changes.push({
                    type: "remove",
                    from: currentPos,
                    to: currentPos + child.nodeSize,
                  });
                }
              } else {
                const images = [];
                child.content.forEach((grandchild) => {
                  if (grandchild.type.name === "image") {
                    images.push(grandchild);
                  }
                });

                if (images.length > 1) {
                  changes.push({
                    type: "split",
                    from: currentPos,
                    to: currentPos + child.nodeSize,
                    images,
                  });
                }
              }
            }
            currentPos += child.nodeSize;
          });

          changes.reverse().forEach((change) => {
            if (change.type === "remove") {
              tr.delete(change.from, change.to);
              modified = true;
            } else if (change.type === "split") {
              const paragraphs = change.images.map((img) => {
                return newState.schema.nodes.paragraph.create({}, [img]);
              });

              tr.replaceWith(change.from, change.to, paragraphs);
              modified = true;
            }
          });
        });

        return modified ? tr.setMeta("addToHistory", false) : null;
      },
    });
  },
};

export default extension;
