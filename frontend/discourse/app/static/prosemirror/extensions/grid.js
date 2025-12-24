import { bind } from "discourse/lib/decorators";
import { iconElement } from "discourse/lib/icon-library";
import { i18n } from "discourse-i18n";

/**
 * Node view for image grid blocks in the rich editor.
 */
class GridNodeView {
  constructor(node, view, getPos) {
    this.node = node;
    this.view = view;
    this.getPos = getPos;

    const div = document.createElement("div");
    div.className = "composer-image-grid";

    const select = document.createElement("select");
    select.className = "composer-image-grid__mode-select";
    select.contentEditable = false;

    const options = [
      { value: "grid", label: i18n("composer.grid_mode_grid") },
      { value: "focus", label: i18n("composer.grid_mode_focus") },
      { value: "stage", label: i18n("composer.grid_mode_stage") },
    ];

    options.forEach((opt) => {
      const option = document.createElement("option");
      option.value = opt.value;
      option.text = opt.label;
      if (node.attrs.mode === opt.value) {
        option.selected = true;
      }
      select.appendChild(option);
    });

    select.addEventListener("change", (e) => {
      const mode = e.target.value;
      const pos = this.getPos();
      this.view.dispatch(
        this.view.state.tr.setNodeMarkup(pos, null, {
          ...this.node.attrs,
          mode,
        })
      );
    });

    div.appendChild(select);

    const contentDiv = document.createElement("div");
    div.appendChild(contentDiv);
    this.contentDOM = contentDiv;

    this.removeBtn = document.createElement("button");
    this.removeBtn.className = "composer-image-grid__remove-btn btn-flat";
    this.removeBtn.appendChild(iconElement("table-cells"));
    const removeLabel = document.createElement("span");
    removeLabel.textContent = i18n("composer.remove_grid");
    this.removeBtn.appendChild(removeLabel);
    this.removeBtn.title = i18n("composer.remove_grid");
    this.removeBtn.type = "button";
    this.removeBtn.contentEditable = false;
    this.removeBtn.addEventListener("click", this.removeClickHandler);

    div.appendChild(this.removeBtn);

    this.dom = div;
  }

  /**
   * Cleans up the node view when it is removed from the editor.
   *
   * @returns {void}
   */
  destroy() {
    this.removeBtn.removeEventListener("click", this.removeClickHandler);
  }

  @bind
  /**
   * Removes the grid node and unwraps its contents.
   *
   * @param {MouseEvent} e
   * @returns {void}
   */
  removeClickHandler(e) {
    e.preventDefault();
    e.stopPropagation();

    const pos = this.getPos();
    const currentNode = this.view.state.doc.nodeAt(pos);
    const tr = this.view.state.tr;

    tr.replaceWith(pos, pos + currentNode.nodeSize, currentNode.content);
    this.view.dispatch(tr);
  }

  /**
   * Applies selection styling to the node view.
   *
   * @returns {void}
   */
  selectNode() {
    this.dom.classList.add("ProseMirror-selectednode");
  }

  /**
   * Removes selection styling from the node view.
   *
   * @returns {void}
   */
  deselectNode() {
    this.dom.classList.remove("ProseMirror-selectednode");
  }

  /**
   * Keeps the node view in sync with editor updates.
   *
   * @param {Object} node
   * @returns {boolean}
   */
  update(node) {
    if (node.type !== this.node.type) {
      return false;
    }
    this.node = node;

    const select = this.dom.querySelector(".composer-image-grid__mode-select");
    if (select && select.value !== node.attrs.mode) {
      select.value = node.attrs.mode;
    }

    return true;
  }
}

/** @type {RichEditorExtension} */
const extension = {
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

  nodeViews: {
    grid: GridNodeView,
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
