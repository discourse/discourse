// It makes sense to use prosemirror-tables for some of the table functionality,
// but it has some differences from our structure (e.g. no thead/tbody).
//
// The main missing part of this extension for now is a UI companion

// Example:
//
// | Left-aligned | Center-aligned | Right-aligned |
// | :---         |     :---:      |          ---: |
// | git status   | git status     | git status    |
// | git diff     | git diff       | git diff      |

/** @type {RichEditorExtension} */
const extension = {
  nodeSpec: {
    table: {
      content: "table_head? table_body",
      group: "block",
      tableRole: "table",
      isolating: true,
      selectable: true,
      draggable: true,
      parseDOM: [{ tag: "table" }],
      toDOM() {
        return ["table", { class: "md-table" }, 0];
      },
    },
    table_head: {
      content: "table_row",
      tableRole: "head",
      isolating: true,
      parseDOM: [{ tag: "thead" }],
      toDOM() {
        return ["thead", 0];
      },
    },
    table_body: {
      content: "table_row+",
      tableRole: "body",
      isolating: true,
      parseDOM: [{ tag: "tbody" }],
      toDOM() {
        return ["tbody", 0];
      },
    },
    table_row: {
      content: "(table_cell | table_header_cell)+",
      tableRole: "row",
      parseDOM: [{ tag: "tr" }],
      toDOM() {
        return ["tr", 0];
      },
    },
    table_header_cell: {
      content: "inline*",
      tableRole: "header_cell",
      attrs: { alignment: { default: null } },
      parseDOM: [
        {
          tag: "th",
          getAttrs(dom) {
            return { alignment: dom.style.textAlign };
          },
        },
      ],
      toDOM(node) {
        return [
          "th",
          {
            style: node.attrs.alignment
              ? `text-align: ${node.attrs.alignment}`
              : undefined,
          },
          0,
        ];
      },
    },
    table_cell: {
      content: "inline*",
      tableRole: "cell",
      attrs: { alignment: { default: null } },
      parseDOM: [
        {
          tag: "td",
          getAttrs(dom) {
            return { alignment: dom.style.textAlign };
          },
        },
      ],
      toDOM(node) {
        return [
          "td",
          {
            style: node.attrs.alignment
              ? `text-align: ${node.attrs.alignment}`
              : undefined,
          },
          0,
        ];
      },
    },
  },
  parse: {
    table: { block: "table" },
    thead: { block: "table_head" },
    tbody: { block: "table_body" },
    tr: { block: "table_row" },
    th: {
      block: "table_header_cell",
      getAttrs(token) {
        return {
          alignment: token.attrGet("style")?.match(/text-align:(\w+)/)?.[1],
        };
      },
    },
    td: {
      block: "table_cell",
      getAttrs(token) {
        return {
          alignment: token.attrGet("style")?.match(/text-align:(\w+)/)?.[1],
        };
      },
    },
  },
  serializeNode: {
    // TODO(renato): state.renderInline should escape `|` if `state.inTable`
    table(state, node) {
      state.flushClose(1);

      let headerBuffer = state.delim;
      const prevInTable = state.inTable;
      state.inTable = true;

      // leading newline, it seems to have issues in a line just below a > blockquote otherwise
      if (state.out) {
        state.out += "\n";
      }

      // group is table_head or table_body
      node.forEach((group, groupOffset, groupIndex) => {
        group.forEach((row) => {
          row.forEach((cell, cellOffset, cellIndex) => {
            if (state.delim && state.atBlank()) {
              state.out += state.delim;
            }
            state.out += cellIndex === 0 ? "| " : " | ";

            state.renderInline(cell);

            // if table_head
            if (groupIndex === 0) {
              if (cell.attrs.alignment === "center") {
                headerBuffer += "|:---:";
              } else if (cell.attrs.alignment === "left") {
                headerBuffer += "|:---";
              } else if (cell.attrs.alignment === "right") {
                headerBuffer += "|---:";
              } else {
                headerBuffer += "|----";
              }
            }
          });

          state.out += " |\n";

          if (headerBuffer) {
            state.out += `${headerBuffer}|\n`;
            headerBuffer = undefined;
          }
        });
      });
      state.out += "\n";
      state.inTable = prevInTable;
    },
    table_head() {},
    table_body() {},
    table_row() {},
    table_header_cell() {},
    table_cell() {},
  },
  plugins({ pmState: { Plugin }, pmModel: { Slice } }) {
    return new Plugin({
      props: {
        transformPasted(paste, view) {
          let updatedPaste = paste;
          paste.content.descendants((child, tableIndex) => {
            if (child.type.name === "table") {
              let tbody, thead;
              child.descendants((node) => {
                if (node.type.name === "table_body") {
                  tbody = node;
                  return false;
                }

                if (node.type.name === "table_head") {
                  thead = node;
                  return false;
                }
              });

              if (!thead && tbody) {
                thead = view.state.schema.nodes.table_head.create(
                  {},
                  tbody.firstChild
                );

                tbody = view.state.schema.nodes.table_body.create(
                  {},
                  tbody.content.content.slice(1)
                );

                const newTableContent = view.state.schema.nodes.table.create(
                  {},
                  [thead, tbody]
                );

                updatedPaste = new Slice(
                  paste.content.replaceChild(tableIndex, newTableContent),
                  paste.openStart,
                  paste.openEnd
                );
              }
            }
          });

          return updatedPaste;
        },
      },
    });
  },
};

export default extension;
