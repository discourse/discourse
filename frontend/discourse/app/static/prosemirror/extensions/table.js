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

function validateTable(node) {
  let hasHead = false;
  let firstRowHasHeaderCells = false;
  let columnCount = 0;
  let hasMultilineCell = false;
  let isFirstRow = true;
  let hasInconsistentColumns = false;

  node.forEach((group) => {
    if (group.type.name === "table_head") {
      hasHead = true;
    }
    group.forEach((row) => {
      if (columnCount === 0) {
        columnCount = row.childCount;
      } else if (row.childCount !== columnCount) {
        hasInconsistentColumns = true;
      }
      if (isFirstRow) {
        let allHeaderCells = true;
        row.forEach((cell) => {
          if (cell.type.name !== "table_header_cell") {
            allHeaderCells = false;
          }
        });
        if (allHeaderCells && row.childCount > 0) {
          firstRowHasHeaderCells = true;
        }
        isFirstRow = false;
      }
      row.forEach((cell) => {
        cell.descendants((n) => {
          if (n.type.name === "hard_break") {
            hasMultilineCell = true;
          }
        });
      });
    });
  });

  const hasValidHeader = hasHead || firstRowHasHeaderCells;

  return {
    isValid:
      hasValidHeader &&
      columnCount >= 2 &&
      !hasMultilineCell &&
      !hasInconsistentColumns,
    hasHead: hasValidHeader,
    columnCount,
    hasMultilineCell,
    hasInconsistentColumns,
  };
}

function serializeTableAsText(state, node) {
  if (state.out) {
    state.out += "\n";
  }

  node.forEach((group) => {
    group.forEach((row) => {
      row.forEach((cell, cellOffset, cellIndex) => {
        if (cellIndex > 0) {
          state.out += " ";
        }
        state.renderInline(cell);
      });
      state.out += "\n";
    });
  });
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

      const prevInTable = state.inTable;
      state.inTable = true;

      // Check if table is valid for markdown format
      const tableInfo = validateTable(node);

      if (!tableInfo.isValid) {
        serializeTableAsText(state, node);
        state.inTable = prevInTable;
        return;
      }

      // leading newline, it seems to have issues in a line just below a > blockquote otherwise
      if (state.out) {
        state.out += "\n";
      }

      // group is table_head or table_body
      let isFirstRow = true;
      node.forEach((group) => {
        const isHead = group.type.name === "table_head";

        group.forEach((row, rowOffset, rowIndex) => {
          const shouldTreatAsHeader =
            isHead ||
            (isFirstRow &&
              rowIndex === 0 &&
              row.childCount > 0 &&
              row.firstChild?.type.name === "table_header_cell");
          let headerBuffer = shouldTreatAsHeader ? state.delim : undefined;

          row.forEach((cell, cellOffset, cellIndex) => {
            if (state.delim && state.atBlank()) {
              state.out += state.delim;
            }
            state.out += cellIndex === 0 ? "| " : " | ";

            state.renderInline(cell);

            if (headerBuffer !== undefined) {
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

          if (headerBuffer !== undefined) {
            state.out += `${headerBuffer}|\n`;
          }
        });
        isFirstRow = false;
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

    /**
     * Checks if a fragment contains any table nodes.
     *
     * @param {Fragment} fragment - The ProseMirror fragment to check
     * @returns {boolean} True if any table nodes exist
     */
    function hasTableNodes(fragment) {
      let found = false;
      fragment.descendants((node) => {
        if (node.type.name === "table") {
          found = true;
          return false;
        }
      });
      return found;
    }

    return new Plugin({
      props: {
        transformPasted(paste, view) {
          // Quick check: only rebuild if tables exist in the paste content
          if (!hasTableNodes(paste.content)) {
            return paste;
          }

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
