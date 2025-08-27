/** @type {RichEditorExtension} */
const extension = {
  // TODO(renato): the rendered date needs to be localized to better match the cooked content
  nodeSpec: {
    local_date: {
      attrs: { date: {}, time: {}, timezone: { default: null } },
      group: "inline",
      inline: true,
      parseDOM: [
        {
          tag: "span.discourse-local-date[data-date]",
          getAttrs: (dom) => {
            return {
              date: dom.getAttribute("data-date"),
              time: dom.getAttribute("data-time"),
              timezone: dom.getAttribute("data-timezone"),
            };
          },
        },
      ],
      toDOM: (node) => {
        const optionalTime = node.attrs.time ? ` ${node.attrs.time}` : "";
        return [
          "span",
          {
            class: "discourse-local-date cooked-date",
            "data-date": node.attrs.date,
            "data-time": node.attrs.time,
            "data-timezone": node.attrs.timezone,
          },
          `${node.attrs.date}${optionalTime}`,
        ];
      },
    },
    local_date_range: {
      attrs: {
        fromDate: {},
        toDate: { default: null },
        fromTime: {},
        toTime: {},
        timezone: { default: null },
      },
      group: "inline",
      inline: true,
      parseDOM: [
        {
          tag: "span.discourse-local-date-range",
          getAttrs: (dom) => {
            return {
              fromDate: dom.dataset.fromDate,
              toDate: dom.dataset.toDate,
              fromTime: dom.dataset.fromTime,
              toTime: dom.dataset.toTime,
              timezone: dom.dataset.timezone,
            };
          },
        },
      ],
      toDOM: (node) => {
        const fromTimeStr = node.attrs.fromTime
          ? ` ${node.attrs.fromTime}`
          : "";
        const toTimeStr = node.attrs.toTime ? ` ${node.attrs.toTime}` : "";
        return [
          "span",
          { class: "discourse-local-date-range" },
          [
            "span",
            {
              class: "discourse-local-date cooked-date",
              "data-range": "from",
              "data-date": node.attrs.fromDate,
              "data-time": node.attrs.fromTime,
              "data-timezone": node.attrs.timezone,
            },
            `${node.attrs.fromDate}${fromTimeStr}`,
          ],
          " → ",
          [
            "span",
            {
              class: "discourse-local-date cooked-date",
              "data-range": "to",
              "data-date": node.attrs.toDate,
              "data-time": node.attrs.toTime,
              "data-timezone": node.attrs.timezone,
            },
            `${node.attrs.toDate}${toTimeStr}`,
          ],
        ];
      },
    },
  },
  parse: {
    span_open(state, token, tokens, i) {
      if (token.attrGet("class") !== "discourse-local-date") {
        return;
      }

      if (token.attrGet("data-range") === "from") {
        state.openNode(state.schema.nodes.local_date_range, {
          fromDate: token.attrGet("data-date"),
          fromTime: token.attrGet("data-time"),
          timezone: token.attrGet("data-timezone"),
        });
        state.__localDateRange = true;
        // we depend on the token data being strictly:
        // [span_open, text, span_close, text, span_open, text, span_close]
        // removing the text occurrences
        tokens.splice(i + 1, 1);
        tokens.splice(i + 2, 1);
        tokens.splice(i + 3, 1);

        return true;
      }

      if (token.attrGet("data-range") === "to") {
        // In our markdown-it tokens, a range is a series of span_open/span_close/span_open/span_close
        // We skip opening a node for `to` and set it on the top node
        state.top().attrs.toDate = token.attrGet("data-date");
        state.top().attrs.toTime = token.attrGet("data-time");
        delete state.__localDateRange;
        return true;
      }

      state.openNode(state.schema.nodes.local_date, {
        date: token.attrGet("data-date"),
        time: token.attrGet("data-time"),
        timezone: token.attrGet("data-timezone"),
      });
      // removing the text occurrence
      tokens.splice(i + 1, 1);
      return true;
    },
    span_close(state) {
      if (["local_date", "local_date_range"].includes(state.top().type.name)) {
        if (!state.__localDateRange) {
          state.closeNode();
        }
        return true;
      }
    },
  },
  serializeNode({ utils: { isBoundary } }) {
    return {
      local_date(state, node, parent, index) {
        state.flushClose();
        if (!isBoundary(state.out, state.out.length - 1)) {
          state.write(" ");
        }

        const optionalTime = node.attrs.time ? ` time=${node.attrs.time}` : "";
        const optionalTimezone = node.attrs.timezone
          ? ` timezone="${node.attrs.timezone}"`
          : "";

        state.write(
          `[date=${node.attrs.date}${optionalTime}${optionalTimezone}]`
        );

        const nextSibling =
          parent.childCount > index + 1 ? parent.child(index + 1) : null;
        if (nextSibling?.isText && !isBoundary(nextSibling.text, 0)) {
          state.write(" ");
        }
      },
      local_date_range(state, node, parent, index) {
        state.flushClose();
        if (!isBoundary(state.out, state.out.length - 1)) {
          state.write(" ");
        }

        const optionalTimezone = node.attrs.timezone
          ? ` timezone="${node.attrs.timezone}"`
          : "";

        const from =
          node.attrs.fromDate +
          (node.attrs.fromTime ? `T${node.attrs.fromTime}` : "");
        const to =
          node.attrs.toDate +
          (node.attrs.toTime ? `T${node.attrs.toTime}` : "");
        state.write(`[date-range from=${from} to=${to}${optionalTimezone}]`);

        const nextSibling =
          parent.childCount > index + 1 ? parent.child(index + 1) : null;
        if (nextSibling?.isText && !isBoundary(nextSibling.text, 0)) {
          state.write(" ");
        }
      },
    };
  },
};

export default extension;
