import { schema } from "prosemirror-markdown";

/** @type {RichEditorExtension} */
const extension = {
  nodeSpec: {
    blockquote: {
      createGapCursor: true,
      ...schema.nodes.blockquote.spec,
    },
    quote: {
      content: "block+",
      group: "block",
      createGapCursor: true,
      defining: true,
      attrs: {
        username: { default: null },
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

        const domSpec = ["aside", attrs];

        if (username) {
          domSpec.push(["div", { class: "title" }, `${username}:`]);
        }

        domSpec.push(["blockquote", 0]);

        return domSpec;
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
    bbcode_open(state, token) {
      if (token.tag === "aside") {
        state.openNode(state.schema.nodes.quote, {
          username: token.attrGet("data-username"),
          postNumber: token.attrGet("data-post"),
          topicId: token.attrGet("data-topic"),
          full: token.attrGet("data-full"),
        });
        return true;
      }

      // ignore the token (no-op), return as handled
      if (token.tag === "blockquote") {
        return true;
      }
    },
    bbcode_close(state, token) {
      if (token.tag === "aside") {
        state.closeNode();
        return true;
      }

      // ignore the token (no-op), return as handled
      if (token.tag === "blockquote") {
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
      const quoteValue = node.attrs.username
        ? `="${node.attrs.username}${postNumber}${topicId}"`
        : "";

      state.write(`[quote${quoteValue}]\n`);
      state.renderContent(node);
      state.write("[/quote]\n\n");
    },
  },
  inputRules: ({ utils: { convertFromMarkdown } }) => ({
    match: /^\[quote([^\]]*)\]$/,
    handler: (state, match, start, end) => {
      const markdown = match[0] + "\n[/quote]";

      return state.tr
        .replaceWith(start - 1, end, convertFromMarkdown(markdown))
        .scrollIntoView();
    },
  }),
  plugins({
    pmState: { Plugin, NodeSelection },
    pmModel: { Slice, Fragment },
  }) {
    return new Plugin({
      props: {
        transformPasted(slice, view) {
          // Prevent quotes that start with a list from being unwrapped during paste.
          // When a quote's first child is a list, Slice.maxOpen opens it too deeply
          // (openStart: 4), causing ProseMirror to unwrap the quote during paste.
          // We detect this case and limit the opening depth.
          let wasFixed = false;
          const firstChild = slice.content.firstChild;
          if (
            firstChild?.type.name === "quote" &&
            slice.openStart > 2 &&
            (firstChild.firstChild?.type.name === "bullet_list" ||
              firstChild.firstChild?.type.name === "ordered_list")
          ) {
            // Limit opening to preserve quote structure while still allowing
            // normal paste merging for quotes with mixed content
            slice = new Slice(slice.content, 1, 1);
            wasFixed = true;
          }

          if (
            view.endOfTextblock("forward") &&
            slice.content.childCount === 1 &&
            slice.content.firstChild.type.name === "quote"
          ) {
            const quote = slice.content.firstChild;
            const paragraph = view.state.schema.nodes.paragraph.create();

            // If we fixed the slice above, preserve those open values.
            // Otherwise use the original behavior (maxOpen with openIsolating=false)
            const result = wasFixed
              ? new Slice(
                  Fragment.from([quote, paragraph]),
                  slice.openStart,
                  slice.openEnd
                )
              : Slice.maxOpen(Fragment.from([quote, paragraph]), false);
            return result;
          }

          return slice;
        },

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

export default extension;
