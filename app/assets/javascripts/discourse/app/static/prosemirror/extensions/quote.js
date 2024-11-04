export default {
  nodeSpec: {
    quote: {
      content: "block+",
      group: "block",
      defining: true,
      inline: false,
      attrs: {
        username: {},
        postNumber: { default: null },
        topicId: { default: null },
        full: { default: null },
      },
      parseDOM: [
        {
          tag: "aside.quote",
          getAttrs(dom) {
            return {
              username: dom.getAttribute("data-username"),
              postNumber: dom.getAttribute("data-post"),
              topicId: dom.getAttribute("data-topic"),
              full: dom.getAttribute("data-full"),
            };
          },
        },
      ],
      toDOM(node) {
        const { username, postNumber, topicId, full } = node.attrs;
        const attrs = { class: "quote" };
        attrs["data-username"] = username;
        attrs["data-post"] = postNumber;
        attrs["data-topic"] = topicId;
        attrs["data-full"] = full ? "true" : "false";

        return ["aside", attrs, 0];
      },
    },
    quote_title: {
      content: "inline*",
      group: "block",
      inline: false,
      parseDOM: [{ tag: "aside[data-username] > div.title" }],
      atom: true,
      draggable: false,
      selectable: false,
      toDOM() {
        return ["div", { class: "title" }, 0];
      },
    },
  },

  parse: {
    quote_header: { block: "quote_title" },
    quote_controls: { ignore: true },
    bbcode(state, token) {
      if (token.tag === "aside") {
        state.openNode(state.schema.nodes.quote, {
          username: token.attrGet("data-username"),
          postNumber: token.attrGet("data-post"),
          topicId: token.attrGet("data-topic"),
          full: token.attrGet("data-full"),
        });
        return true;
      }

      if (token.tag === "blockquote") {
        state.openNode(state.schema.nodes.blockquote);
        return true;
      }
    },
  },

  serializeNode: {
    quote(state, node) {
      const postNumber = node.attrs.postNumber
        ? `, post:${node.attrs.postNumber}`
        : "";
      const topicId = node.attrs.topicId ? `, topic:${node.attrs.topicId}` : "";

      state.write(`[quote="${node.attrs.username}${postNumber}${topicId}"]\n`);
      node.forEach((n) => {
        if (n.type.name === "blockquote") {
          state.renderContent(n);
        }
      });
      state.write("[/quote]\n");
    },
    quote_title() {},
  },
};
