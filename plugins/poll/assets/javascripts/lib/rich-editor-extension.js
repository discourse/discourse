import { buildBBCodeAttrs } from "discourse/lib/text";
import PollNodeView from "../discourse/components/poll-node-view";

/** @type {RichEditorExtension} */
const extension = {
  nodeViews: {
    poll: { component: PollNodeView, name: "poll", hasContent: true },
  },
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
        dynamic: { default: null },
        status: { default: null },
        order: { default: null },
        step: { default: null },
      },
      content: "heading bullet_list poll_info?",
      group: "block",
      selectable: true,
      isolating: true,
      defining: true,
      parseDOM: [
        {
          tag: "div.poll",
          getAttrs: (dom) => {
            const name = dom.getAttribute("data-poll-name");
            const status = dom.getAttribute("data-poll-status");

            return {
              type: dom.getAttribute("data-poll-type"),
              results: dom.getAttribute("data-poll-results"),
              public: dom.getAttribute("data-poll-public"),
              // cooking always writes the defaults out, the markdown doesn't need them
              name: name === "poll" ? null : name,
              chartType: dom.getAttribute("data-poll-charttype"),
              close: dom.getAttribute("data-poll-close"),
              groups: dom.getAttribute("data-poll-groups"),
              dynamic: dom.getAttribute("data-poll-dynamic"),
              max: dom.getAttribute("data-poll-max"),
              min: dom.getAttribute("data-poll-min"),
              status: status === "open" ? null : status,
              order: dom.getAttribute("data-poll-order"),
              step: dom.getAttribute("data-poll-step"),
            };
          },
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
          "data-poll-charttype": node.attrs.chartType,
          "data-poll-close": node.attrs.close,
          "data-poll-groups": node.attrs.groups,
          "data-poll-dynamic": node.attrs.dynamic,
          "data-poll-max": node.attrs.max,
          "data-poll-min": node.attrs.min,
          "data-poll-status": node.attrs.status,
          "data-poll-order": node.attrs.order,
          "data-poll-step": node.attrs.step,
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
        status:
          token.poll_attrs.status === "open" ? null : token.poll_attrs.status,
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
      const attrs = buildBBCodeAttrs(node.attrs);
      state.write(`[poll${attrs ? ` ${attrs}` : ""}]\n`);

      node.forEach((child, offset, index) => {
        // the title node is always present, an untitled poll leaves it empty
        if (child.type.name === "heading" && child.content.size === 0) {
          return;
        }

        // a number poll's options come from its range, not from authored items
        if (child.type.name === "bullet_list" && node.attrs.type === "number") {
          return;
        }

        state.render(child, node, index);
      });

      state.write("[/poll]\n\n");
    },
    poll_info() {},
  },
};

export default extension;
