import formatLocalDate from "./format-local-date";

/** @type {RichEditorExtension} */
const extension = {
  nodeSpec: {
    local_date: {
      attrs: {
        date: {},
        time: {},
        timezone: { default: null },
        format: { default: null },
        recurring: { default: null },
        timezones: { default: null },
        countdown: { default: null },
        displayedTimezone: { default: null },
      },
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
              format: dom.getAttribute("data-format"),
              recurring: dom.getAttribute("data-recurring"),
              timezones: dom.getAttribute("data-timezones"),
              countdown: dom.getAttribute("data-countdown"),
              displayedTimezone: dom.getAttribute("data-displayed-timezone"),
            };
          },
        },
      ],
      toDOM: (node) => {
        const options = {
          format: node.attrs.format,
          recurring: node.attrs.recurring,
          countdown: node.attrs.countdown,
          displayedTimezone: node.attrs.displayedTimezone,
          timezones: node.attrs.timezones?.split("|"),
        };
        const { formatted } = formatLocalDate(
          node.attrs.date,
          node.attrs.time,
          node.attrs.timezone,
          options
        );
        const attrs = {
          class: "discourse-local-date cooked-date",
          "data-date": node.attrs.date,
          "data-time": node.attrs.time,
          "data-timezone": node.attrs.timezone,
        };
        if (node.attrs.format) {
          attrs["data-format"] = node.attrs.format;
        }
        if (node.attrs.recurring) {
          attrs["data-recurring"] = node.attrs.recurring;
        }
        if (node.attrs.timezones) {
          attrs["data-timezones"] = node.attrs.timezones;
        }
        if (node.attrs.countdown) {
          attrs["data-countdown"] = node.attrs.countdown;
        }
        if (node.attrs.displayedTimezone) {
          attrs["data-displayed-timezone"] = node.attrs.displayedTimezone;
        }
        return ["span", attrs, formatted];
      },
    },
    local_date_range: {
      attrs: {
        fromDate: {},
        toDate: { default: null },
        fromTime: {},
        toTime: {},
        timezone: { default: null },
        format: { default: null },
        timezones: { default: null },
        countdown: { default: null },
        displayedTimezone: { default: null },
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
              format: dom.dataset.format,
              timezones: dom.dataset.timezones,
              countdown: dom.dataset.countdown,
              displayedTimezone: dom.dataset.displayedTimezone,
            };
          },
        },
      ],
      toDOM: (node) => {
        const options = {
          format: node.attrs.format,
          countdown: node.attrs.countdown,
          displayedTimezone: node.attrs.displayedTimezone,
          timezones: node.attrs.timezones?.split("|"),
        };
        const { formatted: formattedFrom } = formatLocalDate(
          node.attrs.fromDate,
          node.attrs.fromTime,
          node.attrs.timezone,
          options
        );
        const { formatted: formattedTo } = formatLocalDate(
          node.attrs.toDate,
          node.attrs.toTime,
          node.attrs.timezone,
          options
        );
        const fromAttrs = {
          class: "discourse-local-date cooked-date",
          "data-range": "from",
          "data-date": node.attrs.fromDate,
          "data-time": node.attrs.fromTime,
          "data-timezone": node.attrs.timezone,
        };
        const toAttrs = {
          class: "discourse-local-date cooked-date",
          "data-range": "to",
          "data-date": node.attrs.toDate,
          "data-time": node.attrs.toTime,
          "data-timezone": node.attrs.timezone,
        };
        if (node.attrs.format) {
          fromAttrs["data-format"] = node.attrs.format;
          toAttrs["data-format"] = node.attrs.format;
        }
        if (node.attrs.timezones) {
          fromAttrs["data-timezones"] = node.attrs.timezones;
          toAttrs["data-timezones"] = node.attrs.timezones;
        }
        if (node.attrs.countdown) {
          fromAttrs["data-countdown"] = node.attrs.countdown;
          toAttrs["data-countdown"] = node.attrs.countdown;
        }
        if (node.attrs.displayedTimezone) {
          fromAttrs["data-displayed-timezone"] = node.attrs.displayedTimezone;
          toAttrs["data-displayed-timezone"] = node.attrs.displayedTimezone;
        }
        return [
          "span",
          { class: "discourse-local-date-range" },
          ["span", fromAttrs, formattedFrom],
          " → ",
          ["span", toAttrs, formattedTo],
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
          format: token.attrGet("data-format"),
          timezones: token.attrGet("data-timezones"),
          countdown: token.attrGet("data-countdown"),
          displayedTimezone: token.attrGet("data-displayed-timezone"),
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
        format: token.attrGet("data-format"),
        recurring: token.attrGet("data-recurring"),
        timezones: token.attrGet("data-timezones"),
        countdown: token.attrGet("data-countdown"),
        displayedTimezone: token.attrGet("data-displayed-timezone"),
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
        const optionalFormat = node.attrs.format
          ? ` format="${node.attrs.format}"`
          : "";
        const optionalRecurring = node.attrs.recurring
          ? ` recurring="${node.attrs.recurring}"`
          : "";
        const optionalTimezones = node.attrs.timezones
          ? ` timezones="${node.attrs.timezones}"`
          : "";
        const optionalCountdown = node.attrs.countdown
          ? ` countdown="${node.attrs.countdown}"`
          : "";
        const optionalDisplayedTimezone = node.attrs.displayedTimezone
          ? ` displayedTimezone="${node.attrs.displayedTimezone}"`
          : "";

        state.write(
          `[date=${node.attrs.date}${optionalTime}${optionalTimezone}${optionalFormat}${optionalRecurring}${optionalTimezones}${optionalCountdown}${optionalDisplayedTimezone}]`
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
        const optionalFormat = node.attrs.format
          ? ` format="${node.attrs.format}"`
          : "";
        const optionalTimezones = node.attrs.timezones
          ? ` timezones="${node.attrs.timezones}"`
          : "";
        const optionalCountdown = node.attrs.countdown
          ? ` countdown="${node.attrs.countdown}"`
          : "";
        const optionalDisplayedTimezone = node.attrs.displayedTimezone
          ? ` displayedTimezone="${node.attrs.displayedTimezone}"`
          : "";

        const from =
          node.attrs.fromDate +
          (node.attrs.fromTime ? `T${node.attrs.fromTime}` : "");
        const to =
          node.attrs.toDate +
          (node.attrs.toTime ? `T${node.attrs.toTime}` : "");
        state.write(
          `[date-range from=${from} to=${to}${optionalTimezone}${optionalFormat}${optionalTimezones}${optionalCountdown}${optionalDisplayedTimezone}]`
        );

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
