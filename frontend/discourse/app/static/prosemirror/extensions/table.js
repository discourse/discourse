// Markdown Table Example:
//
// | Left-aligned | Center-aligned | Right-aligned |
// | :---         |     :---:      |          ---: |
// | git status   | git status     | git status    |
// | git diff     | git diff       | git diff      |

class TableNodeView {
  constructor() {
    const div = document.createElement("div");
    div.classList.add("md-table");
    const table = document.createElement("table");
    div.appendChild(table);

    this.dom = div;
    this.contentDOM = table;
  }
}

/** @type {import("discourse/lib/composer/rich-editor-extensions").RichEditorExtension} */
const extension = {
  nodeViews: { table: TableNodeView },
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
  plugins({ pmState: { Plugin }, pmModel: { Slice, Fragment } }) {
    function findMaxColumns(tbody) {
      let maxColumns = 0;
      tbody.forEach((row) => {
        maxColumns = Math.max(maxColumns, row.childCount);
      });
      return maxColumns;
    }

    function createHeaderRow(firstRow, maxColumns, schema) {
      const headerCells = [];
      for (let i = 0; i < maxColumns; i++) {
        if (i < firstRow.childCount) {
          const cell = firstRow.child(i);
          headerCells.push(
            schema.nodes.table_header_cell.create(cell.attrs, cell.content)
          );
        } else {
          headerCells.push(schema.nodes.table_header_cell.create());
        }
      }
      return schema.nodes.table_row.create({}, headerCells);
    }

    function createBodyRows(tbody, maxColumns, schema) {
      const bodyRows = [];
      tbody.content.content.slice(1).forEach((row) => {
        const cells = [];
        for (let i = 0; i < maxColumns; i++) {
          if (i < row.childCount) {
            cells.push(row.child(i));
          } else {
            cells.push(schema.nodes.table_cell.create());
          }
        }
        bodyRows.push(schema.nodes.table_row.create({}, cells));
      });
      return bodyRows;
    }

    function normalizeTable(tableNode, schema) {
      let tbody, thead;
      tableNode.descendants((node) => {
        if (node.type.name === "table_body") {
          tbody = node;
          return false;
        }
        if (node.type.name === "table_head") {
          thead = node;
          return false;
        }
      });

      if (thead || !tbody) {
        return tableNode;
      }

      const maxColumns = findMaxColumns(tbody);
      const firstRow = tbody.firstChild;

      if (!firstRow || maxColumns === 0) {
        return tableNode;
      }

      const header = schema.nodes.table_head.create(
        {},
        createHeaderRow(firstRow, maxColumns, schema)
      );

      const body = schema.nodes.table_body.create(
        {},
        createBodyRows(tbody, maxColumns, schema)
      );

      return schema.nodes.table.create({}, [header, body]);
    }

    return new Plugin({
      props: {
        transformPasted(paste, view) {
          const schema = view.state.schema;

          function transformNode(node) {
            if (node.type.name === "table") {
              return normalizeTable(node, schema);
            }

            if (node.content?.size > 0) {
              const newChildren = node.content.content.map(transformNode);
              return node.type.create(node.attrs, newChildren, node.marks);
            }

            return node;
          }

          const transformedContent = paste.content.content.map(transformNode);

          return new Slice(
            Fragment.from(transformedContent),
            paste.openStart,
            paste.openEnd
          );
        },
      },
    });
  },
};

export default extension;
