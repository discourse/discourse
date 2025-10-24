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
        avatarHtml: { default: null },
      },
      parseDOM: [
        {
          tag: "aside.quote",
          contentElement: "blockquote",
          getAttrs(dom) {
            const titleDiv = dom.querySelector(".title");
            const avatarImg = titleDiv?.querySelector("img.avatar");
            return {
              username: dom.getAttribute("data-username"),
              postNumber: dom.getAttribute("data-post"),
              topicId: dom.getAttribute("data-topic"),
              full: dom.getAttribute("data-full"),
              avatarHtml: avatarImg ? avatarImg.outerHTML : null,
            };
          },
        },
      ],
      toDOM(node) {
        const { username, postNumber, topicId, full, avatarHtml } = node.attrs;
        const attrs = { class: "quote" };
        attrs["data-username"] = username;
        attrs["data-post"] = postNumber;
        attrs["data-topic"] = topicId;
        attrs["data-full"] = full ? "true" : "false";

        const domSpec = ["aside", attrs];

        if (username) {
          const titleChildren = [];

          // Add avatar if present
          if (avatarHtml) {
            try {
              const tempDiv = document.createElement("div");
              tempDiv.innerHTML = avatarHtml;
              const avatarNode = tempDiv.firstChild;

              if (
                avatarNode &&
                avatarNode.tagName &&
                avatarNode.tagName.toUpperCase() === "IMG"
              ) {
                const imgAttrs = {
                  alt: avatarNode.getAttribute("alt") || "",
                  width: avatarNode.getAttribute("width") || "20",
                  height: avatarNode.getAttribute("height") || "20",
                  src: avatarNode.getAttribute("src") || "",
                  class: avatarNode.getAttribute("class") || "avatar",
                };
                titleChildren.push(["img", imgAttrs]);
              }
            } catch {
              // If parsing fails, continue without avatar
            }
          }

          titleChildren.push(`${username}:`);

          domSpec.push(["div", { class: "title" }, ...titleChildren]);
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

      // Look for html_inline token containing avatar img and store it
      let avatarHtml = null;
      for (let j = i + 1; j < Math.min(i + 10, tokens.length); j++) {
        if (
          tokens[j].type === "html_inline" &&
          tokens[j].content.includes('class="avatar"')
        ) {
          avatarHtml = tokens[j].content;
          break;
        }
        if (tokens[j].type === "quote_header_close") {
          break;
        }
      }

      // Store the avatar HTML in a meta field for access in bbcode_open
      state._currentQuoteAvatarHtml = avatarHtml;
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
          avatarHtml: state._currentQuoteAvatarHtml || null,
        });
        state._currentQuoteAvatarHtml = null;
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
    getContext,
  }) {
    return [
      new Plugin({
        appendTransaction(transactions, oldState, newState) {
          const context = getContext();
          const lookupAvatar =
            context?.markdownOptions?.lookupAvatarByPostNumber;

          if (!lookupAvatar) {
            return null;
          }

          let tr = null;

          newState.doc.descendants((node, pos) => {
            if (
              node.type.name === "quote" &&
              node.attrs.username &&
              node.attrs.postNumber &&
              node.attrs.topicId &&
              !node.attrs.avatarHtml
            ) {
              const avatarHtml = lookupAvatar(
                node.attrs.postNumber,
                node.attrs.topicId
              );

              if (avatarHtml) {
                if (!tr) {
                  tr = newState.tr;
                }
                tr.setNodeMarkup(pos, null, {
                  ...node.attrs,
                  avatarHtml,
                });
              }
            }
          });

          return tr;
        },
      }),
      new Plugin({
        props: {
          transformPasted(slice, view) {
            if (
              view.endOfTextblock("forward") &&
              slice.content.childCount === 1 &&
              slice.content.firstChild.type.name === "quote"
            ) {
              const quote = slice.content.firstChild;
              const paragraph = view.state.schema.nodes.paragraph.create();

              return Slice.maxOpen(Fragment.from([quote, paragraph]), false);
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
      }),
    ];
  },
};

export default extension;
