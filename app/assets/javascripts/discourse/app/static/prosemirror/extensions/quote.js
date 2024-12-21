export default {
  nodeSpec: {
    quote: {
      content: "block+",
      group: "block",
      inline: false,
      selectable: true,
      isolating: true,
      attrs: {
        username: {},
        postNumber: { default: null },
        topicId: { default: null },
        full: { default: null },
      },
      parseDOM: [
        {
          tag: "aside.quote",
          contentElement: "blockquote",
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

        const quoteTitle = ["div", { class: "title" }, `${username}:`];

        return ["aside", attrs, quoteTitle, ["blockquote", 0]];
      },
    },
  },

  parse: {
    quote_header_open(state, token, tokens, i) {
      // removing the text child, this depends on the current token order:
      // quote_header_open quote_controls_open quote_controls_close text quote_header_close
      // otherwise it's hard to get a "quote_title" node to behave the way we need
      // (a contentEditable=false node breaks the keyboard nav, among other issues)
      tokens[i + 3].content = "";
    },
    quote_header_close() {},
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
    },
  },

  serializeNode: {
    quote(state, node) {
      const postNumber = node.attrs.postNumber
        ? `, post:${node.attrs.postNumber}`
        : "";
      const topicId = node.attrs.topicId ? `, topic:${node.attrs.topicId}` : "";

      state.write(`[quote="${node.attrs.username}${postNumber}${topicId}"]\n`);
      state.renderContent(node);
      state.write("[/quote]\n\n");
    },
  },
  plugins({ Plugin, NodeSelection }) {
    return new Plugin({
      props: {
        handleClickOn(view, pos, node, nodePos, event) {
          if (
            node.type.name === "quote" &&
            event.target.classList.contains("title")
          ) {
            view.dispatch(
              view.state.tr.setSelection(
                NodeSelection.create(view.state.doc, nodePos)
              )
            );

            return true;
          }
        },
      },
    });
  },
};
