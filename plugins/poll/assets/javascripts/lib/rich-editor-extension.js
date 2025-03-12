/** @type {RichEditorExtension} */
const extension = {
  nodeSpec: {
    poll: {
      attrs: {
        type: { default: null },
        results: { default: null },
        public: { default: null },
        name: { default: null },
        chartType: { default: null },
        close: { default: null },
        groups: { default: null },
        max: { default: null },
        min: { default: null },
      },
      content: "heading? bullet_list poll_info?",
      group: "block",
      draggable: true,
      selectable: true,
      isolating: true,
      defining: true,
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
    poll_info: {
      content: "inline*",
      selectable: false,
      isolating: true,
      parseDOM: [{ tag: "div.poll-info" }],
      toDOM: () => ["div", { class: "poll-info", contentEditable: false }, 0],
    },
  },
  parse: {
    poll: {
      block: "poll",
      getAttrs: (token) => ({
        ...token.poll_attrs,
        name: token.poll_attrs.name === "poll" ? null : token.poll_attrs.name,
      }),
    },
    poll_container: { ignore: true },
    poll_title: { block: "heading" },
    poll_info: { block: "poll_info" },
    poll_info_counts: { ignore: true },
    poll_info_counts_count: { ignore: true },
    poll_info_number: { ignore: true },
    poll_info_label_open(state) {
      state.addText(" ");
    },
    poll_info_label_close() {},
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
    poll_info() {},
  },
};

export default extension;
