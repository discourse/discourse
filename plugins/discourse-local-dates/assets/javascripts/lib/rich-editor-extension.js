import { buildBBCodeAttrs } from "discourse/lib/text";
import formatLocalDate from "./format-local-date";

const OPTIONAL_DATA_ATTRS = [
  "format",
  "recurring",
  "timezones",
  "countdown",
  "displayedTimezone",
];

/**
 * Adds optional data attributes to a DOM attributes object
 * @param {Object} attrs - The attributes object to modify
 * @param {Object} nodeAttrs - The node attributes to read from
 * @param {string[]} keys - The keys to process
 */
function addOptionalDataAttrs(attrs, nodeAttrs, keys = OPTIONAL_DATA_ATTRS) {
  for (const key of keys) {
    if (nodeAttrs[key]) {
      const dataKey =
        key === "displayedTimezone" ? "data-displayed-timezone" : `data-${key}`;
      attrs[dataKey] = nodeAttrs[key];
    }
  }
}

/**
 * Builds format options from node attributes
 * @param {Object} nodeAttrs - The node attributes
 * @param {boolean} includeRecurring - Whether to include the recurring option
 * @returns {Object} The options object for formatLocalDate
 */
function buildFormatOptions(nodeAttrs, includeRecurring = false) {
  const options = {
    format: nodeAttrs.format,
    countdown: nodeAttrs.countdown,
    displayedTimezone: nodeAttrs.displayedTimezone,
    timezones: nodeAttrs.timezones?.split("|"),
  };
  if (includeRecurring) {
    options.recurring = nodeAttrs.recurring;
  }
  return options;
}

/** @type {RichEditorExtension} */
const extension = {
  nodeSpec: {
    local_date: {
      attrs: {
        date: {},
        time: { default: null },
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
              date: dom.dataset.date,
              time: dom.dataset.time,
              timezone: dom.dataset.timezone,
              format: dom.dataset.format,
              recurring: dom.dataset.recurring,
              timezones: dom.dataset.timezones,
              countdown: dom.dataset.countdown,
              displayedTimezone: dom.dataset.displayedTimezone,
            };
          },
        },
      ],
      toDOM: (node) => {
        const options = buildFormatOptions(node.attrs, true);
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
        addOptionalDataAttrs(attrs, node.attrs);
        return ["span", attrs, formatted];
      },
    },
    local_date_range: {
      attrs: {
        fromDate: {},
        toDate: { default: null },
        fromTime: { default: null },
        toTime: { default: null },
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
            const fromSpan = dom.querySelector('[data-range="from"]');
            const toSpan = dom.querySelector('[data-range="to"]');
            if (!fromSpan) {
              return false;
            }
            return {
              fromDate: fromSpan.dataset.date,
              toDate: toSpan?.dataset.date,
              fromTime: fromSpan.dataset.time,
              toTime: toSpan?.dataset.time,
              timezone: fromSpan.dataset.timezone,
              format: fromSpan.dataset.format,
              timezones: fromSpan.dataset.timezones,
              countdown: fromSpan.dataset.countdown,
              displayedTimezone: fromSpan.dataset.displayedTimezone,
            };
          },
        },
      ],
      toDOM: (node) => {
        const options = buildFormatOptions(node.attrs);
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
        const rangeAttrs = [
          "format",
          "timezones",
          "countdown",
          "displayedTimezone",
        ];
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
        addOptionalDataAttrs(fromAttrs, node.attrs, rangeAttrs);
        addOptionalDataAttrs(toAttrs, node.attrs, rangeAttrs);
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

        const { date, ...rest } = node.attrs;
        const optionalAttrs = buildBBCodeAttrs(rest);
        state.write(
          `[date=${date}${optionalAttrs ? ` ${optionalAttrs}` : ""}]`
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

        const { fromDate, toDate, fromTime, toTime, ...rest } = node.attrs;
        const from = fromDate + (fromTime ? `T${fromTime}` : "");
        const to = toDate + (toTime ? `T${toTime}` : "");
        const optionalAttrs = buildBBCodeAttrs(rest);
        state.write(
          `[date-range from=${from} to=${to}${optionalAttrs ? ` ${optionalAttrs}` : ""}]`
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
