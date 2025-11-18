import { bind } from "discourse/lib/decorators";
import { iconHTML } from "discourse/lib/icon-library";
import { i18n } from "discourse-i18n";

class GridNodeView {
  constructor(node, view, getPos) {
    this.node = node;
    this.view = view;
    this.getPos = getPos;

    const div = document.createElement("div");
    div.className = "composer-image-grid";

    const title = document.createElement("div");
    title.className = "composer-image-grid__title";
    title.innerHTML = iconHTML("table-cells");
    title.prepend(document.createTextNode(i18n("composer.grid_label")));

    div.appendChild(title);

    const contentDiv = document.createElement("div");
    div.appendChild(contentDiv);

    this.dom = div;
    this.contentDOM = contentDiv;

    this.svg = div.querySelector("svg");
    this.svg.setAttribute("alt", i18n("composer.toggle_image_grid"));
    this.svg.addEventListener("click", this.iconClickHandler);
  }

  @bind
  iconClickHandler() {
    const pos = this.getPos();
    const currentNode = this.view.state.doc.nodeAt(pos);
    const tr = this.view.state.tr;

    tr.replaceWith(pos, pos + currentNode.nodeSize, currentNode.content);
    this.view.dispatch(tr);
  }

  selectNode() {
    this.dom.classList.add("ProseMirror-selectednode");
  }

  deselectNode() {
    this.dom.classList.remove("ProseMirror-selectednode");
  }

  update(node) {
    return node.type === this.node.type;
  }

  destroy() {
    this.svg.removeEventListener("click", this.iconClickHandler);
  }
}

/** @type {RichEditorExtension} */
const extension = {
  nodeSpec: {
    grid: {
      content: "block+",
      group: "block",
      createGapCursor: true,
      parseDOM: [
        { tag: "div.d-image-grid" },
        { tag: "div.composer-image-grid" },
      ],
      toDOM() {
        return ["div", { class: "composer-image-grid" }, 0];
      },
    },
  },

  nodeViews: {
    grid: GridNodeView,
  },

  parse: {
    bbcode_open(state, token) {
      if (token.attrGet("class") === "d-image-grid") {
        state.openNode(state.schema.nodes.grid);
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
      state.write("\n[grid]\n\n");
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

  plugins({ pmState: { Plugin, PluginKey } }) {
    const gridCleanupPlugin = new PluginKey("grid-cleanup");

    return new Plugin({
      key: gridCleanupPlugin,
      appendTransaction(transactions, oldState, newState) {
        // Only process if the document actually changed
        if (!transactions.some((tr) => tr.docChanged)) {
          return null;
        }

        const tr = newState.tr;
        let modified = false;

        // Process grids from end to beginning to avoid position shifts
        const gridNodes = [];
        newState.doc.descendants((node, pos) => {
          if (node.type.name === "grid") {
            gridNodes.push({ node, pos });
          }
        });

        gridNodes.reverse().forEach(({ node, pos }) => {
          // If grid is completely empty, remove it
          if (node.childCount === 0) {
            tr.delete(pos, pos + node.nodeSize);
            modified = true;
            return;
          }

          const changes = [];
          let currentPos = pos + 1; // Start inside the grid node

          node.content.forEach((child) => {
            if (child.type.name === "paragraph") {
              if (child.content.size === 0) {
                // Only remove empty paragraph if grid has other content
                if (node.childCount > 1) {
                  changes.push({
                    type: "remove",
                    from: currentPos,
                    to: currentPos + child.nodeSize,
                  });
                }
              } else {
                // Split paragraphs with multiple images
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
