import { bind } from "discourse/lib/decorators";
import { iconElement } from "discourse/lib/icon-library";
import { i18n } from "discourse-i18n";

class GridNodeView {
  constructor(node, view, getPos) {
    this.node = node;
    this.view = view;
    this.getPos = getPos;

    const div = document.createElement("div");
    div.className = "composer-image-grid";

    const modeGroup = document.createElement("div");
    modeGroup.className = "composer-image-gallery__mode-buttons";
    modeGroup.setAttribute("role", "group");
    modeGroup.contentEditable = false;

    const modes = [
      {
        value: "grid",
        label: i18n("composer.grid_mode_grid"),
        icon: "table-cells",
      },
      {
        value: "carousel",
        label: i18n("composer.grid_mode_carousel"),
        icon: "image",
      },
    ];

    modes.forEach((opt) => {
      const button = document.createElement("button");
      button.type = "button";
      button.className = "composer-image-gallery__mode-btn";
      button.dataset.mode = opt.value;
      button.appendChild(iconElement(opt.icon));
      const textLabel = document.createElement("span");
      textLabel.textContent = opt.label;
      button.appendChild(textLabel);
      button.ariaLabel = opt.label;
      button.title = i18n("composer.grid_mode_title", { mode: opt.label });
      if (node.attrs.mode === opt.value) {
        button.classList.add("is-active");
        button.setAttribute("aria-pressed", "true");
      } else {
        button.setAttribute("aria-pressed", "false");
      }

      button.addEventListener("click", (e) => {
        e.preventDefault();
        const mode = opt.value;
        const pos = this.getPos();
        this.view.dispatch(
          this.view.state.tr.setNodeMarkup(pos, null, {
            ...this.node.attrs,
            mode,
          })
        );
      });

      modeGroup.appendChild(button);
    });

    div.appendChild(modeGroup);

    const contentDiv = document.createElement("div");
    div.appendChild(contentDiv);
    this.contentDOM = contentDiv;

    this.removeBtn = document.createElement("button");
    this.removeBtn.className = "composer-image-grid__remove-btn";
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

  destroy() {
    this.removeBtn.removeEventListener("click", this.removeClickHandler);
  }

  @bind
  removeClickHandler(e) {
    e.preventDefault();
    e.stopPropagation();

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
    if (node.type !== this.node.type) {
      return false;
    }
    this.node = node;

    const buttons = this.dom.querySelectorAll(
      ".composer-image-gallery__mode-btn"
    );
    buttons.forEach((btn) => {
      if (btn.dataset.mode === node.attrs.mode) {
        btn.classList.add("is-active");
        btn.setAttribute("aria-pressed", "true");
      } else {
        btn.classList.remove("is-active");
        btn.setAttribute("aria-pressed", "false");
      }
    });

    return true;
  }
}

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
