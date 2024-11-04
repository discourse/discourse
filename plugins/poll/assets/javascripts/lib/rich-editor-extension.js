export default {
  nodeSpec: {
    poll: {
      attrs: {
        type: {},
        results: {},
        public: {},
        name: {},
        chartType: {},
        close: { default: null },
        groups: { default: null },
        max: { default: null },
        min: { default: null },
      },
      content: "poll_container poll_info",
      group: "block",
      draggable: true,
      parseDOM: [
        {
          tag: "div.poll",
          getAttrs: (dom) => ({
            type: dom.getAttribute("data-poll-type"),
            results: dom.getAttribute("data-poll-results"),
            public: dom.getAttribute("data-poll-public"),
            name: dom.getAttribute("data-poll-name"),
            chartType: dom.getAttribute("data-poll-chart-type"),
            close: dom.getAttribute("data-poll-close"),
            groups: dom.getAttribute("data-poll-groups"),
            max: dom.getAttribute("data-poll-max"),
            min: dom.getAttribute("data-poll-min"),
          }),
        },
      ],
      toDOM: (node) => [
        "div",
        {
          class: "poll",
          "data-poll-type": node.attrs.type,
          "data-poll-results": node.attrs.results,
          "data-poll-public": node.attrs.public,
          "data-poll-name": node.attrs.name,
          "data-poll-chart-type": node.attrs.chartType,
          "data-poll-close": node.attrs.close,
          "data-poll-groups": node.attrs.groups,
          "data-poll-max": node.attrs.max,
          "data-poll-min": node.attrs.min,
        },
        0,
      ],
    },
    poll_container: {
      content: "heading? bullet_list",
      group: "block",
      parseDOM: [{ tag: "div.poll-container" }],
      toDOM: () => ["div", { class: "poll-container" }, 0],
    },
    poll_info: {
      content: "inline*",
      group: "block",
      atom: true,
      selectable: false,
      parseDOM: [{ tag: "div.poll-info" }],
      toDOM: () => ["div", { class: "poll-info", contentEditable: false }, 0],
    },
  },
  parse: {
    poll: {
      block: "poll",
      getAttrs: (token) => ({
        type: token.attrGet("data-poll-type"),
        results: token.attrGet("data-poll-results"),
        public: token.attrGet("data-poll-public"),
        name: token.attrGet("data-poll-name"),
        chartType: token.attrGet("data-poll-chart-type"),
        close: token.attrGet("data-poll-close"),
        groups: token.attrGet("data-poll-groups"),
        max: token.attrGet("data-poll-max"),
        min: token.attrGet("data-poll-min"),
      }),
    },
    poll_container: { block: "poll_container" },
    poll_title: { block: "heading" },
    poll_info: { block: "poll_info" },
    poll_info_counts: { ignore: true },
    poll_info_counts_count: { ignore: true },
    poll_info_number: { ignore: true },
    poll_info_label: { ignore: true },
  },
  serializeNode: {
    poll(state, node) {
      const attrs = Object.entries(node.attrs)
        .map(([key, value]) => (value ? ` ${key}="${value}"` : ""))
        .join("");

      state.write(`[poll${attrs}]\n`);
      state.renderContent(node);
      state.write("[/poll]\n\n");
    },
    poll_container(state, node) {
      state.renderContent(node);
    },
    poll_info() {},
  },
};
