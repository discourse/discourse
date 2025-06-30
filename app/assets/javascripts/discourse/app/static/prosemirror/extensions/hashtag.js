import { ajax } from "discourse/lib/ajax";
import { getHashtagTypeClasses } from "discourse/lib/hashtag-type-registry";
import { emojiUnescape } from "discourse/lib/text";
import { isBoundary } from "discourse/static/prosemirror/lib/markdown-it";

const VALID_HASHTAGS = new Map();
const INVALID_HASHTAGS = new Set();

/** @type {RichEditorExtension} */
const extension = {
  nodeSpec: {
    hashtag: {
      attrs: {
        name: {},
        processed: { default: false },
        valid: { default: true },
      },
      inline: true,
      group: "inline",
      draggable: true,
      selectable: false,
      parseDOM: [
        {
          tag: "a.hashtag-cooked",
          preserveWhitespace: "full",
          getAttrs: (dom) => {
            return {
              name: dom.getAttribute("data-name"),
              processed: dom.getAttribute("data-processed"),
              valid: dom.getAttribute("data-valid"),
            };
          },
        },
      ],
      toDOM: (node) => {
        return [
          "a",
          {
            class: "hashtag-cooked",
            "data-name": node.attrs.name,
            "data-processed": node.attrs.processed,
            "data-valid": node.attrs.valid,
          },
          `#${node.attrs.name}`,
        ];
      },
    },
  },

  inputRules: [
    {
      match: /(^|\W)(#[\u00C0-\u1FFF\u2C00-\uD7FF\w:-]{1,101})\s$/,
      handler: (state, match, start, end) => {
        const hashtagStart = start + match[1].length;
        const name = match[2].slice(1);
        return (
          state.selection.$from.nodeBefore?.type !==
            state.schema.nodes.hashtag &&
          state.tr.replaceWith(hashtagStart, end, [
            state.schema.nodes.hashtag.create({ name }),
            state.schema.text(" "),
          ])
        );
      },
      options: { undoable: false },
    },
  ],

  parse: {
    span_open(state, token, tokens, i) {
      if (token.attrGet("class") === "hashtag-raw") {
        state.openNode(state.schema.nodes.hashtag, {
          // this is not ideal, but working around the span_open/close structure
          // a text is expected just after the span_open token
          name: tokens.splice(i + 1, 1)[0].content.slice(1),
        });
        return true;
      }
    },
    span_close(state) {
      if (state.top().type.name === "hashtag") {
        state.closeNode();
        return true;
      }
    },
  },

  serializeNode: {
    hashtag(state, node, parent, index) {
      state.flushClose();
      if (!isBoundary(state.out, state.out.length - 1)) {
        state.write(" ");
      }

      state.write(`#${node.attrs.name}`);

      const nextSibling =
        parent.childCount > index + 1 ? parent.child(index + 1) : null;
      if (nextSibling?.isText && !isBoundary(nextSibling.text, 0)) {
        state.write(" ");
      }
    },
  },
  plugins({ pmState: { Plugin, PluginKey }, getContext }) {
    const key = new PluginKey("hashtag");

    return new Plugin({
      key,
      view() {
        return {
          update(view) {
            this.processHashtags(view);
          },
          processHashtags(view) {
            const hashtagNames = [];
            const hashtagNodes = [];

            view.state.doc.descendants((node, pos) => {
              if (
                node.type.name !== "hashtag" ||
                node.attrs.processed ||
                !node.attrs.valid
              ) {
                return;
              }

              const name = node.attrs.name;
              hashtagNodes.push({ name, node, pos });
              hashtagNames.push(name);
            });

            if (!hashtagNodes.length) {
              return;
            }

            // process in reverse to avoid issues with position shifts
            hashtagNodes.sort((a, b) => b.pos - a.pos);

            const updateHashtags = async () => {
              await fetchHashtags(hashtagNames, getContext());

              for (const hashtagNode of hashtagNodes) {
                const { name, node, pos } = hashtagNode;
                const validHashtag = VALID_HASHTAGS.get(name.toLowerCase());

                // check if node still exists at this position before updating
                if (view.state.doc.nodeAt(pos)?.type !== node.type) {
                  continue;
                }

                view.dispatch(
                  view.state.tr.setNodeMarkup(pos, null, {
                    ...node.attrs,
                    processed: true,
                    valid: !!validHashtag,
                  })
                );

                const domNode = view.nodeDOM(pos);
                if (!validHashtag || !domNode) {
                  continue;
                }

                // decorate valid hashtags based on their type
                const tagText = emojiUnescape(validHashtag?.text || name);
                const hashtagTypeClass =
                  getHashtagTypeClasses()[validHashtag.type];
                const hashtagIconHTML = hashtagTypeClass
                  .generateIconHTML(validHashtag)
                  .trim();

                domNode.innerHTML = `${hashtagIconHTML}${tagText}`;
              }
            };

            updateHashtags();
          },
        };
      },
    });
  },
};

async function fetchHashtags(hashtags, context) {
  const slugs = hashtags.filter(
    (tag) => !VALID_HASHTAGS.has(tag) && !INVALID_HASHTAGS.has(tag)
  );

  if (!slugs.length) {
    return;
  }

  const order = context.site.hashtag_configurations["topic-composer"];
  const response = await ajax("/hashtags", { data: { slugs, order } });

  const validTags = Object.values(response || {})
    .flat()
    .filter(Boolean);

  validTags.forEach((tag) => {
    VALID_HASHTAGS.set(tag.ref, tag);
    hashtags.splice(hashtags.indexOf(tag.ref), 1);
  });

  // mark remaining hashtags as invalid to avoid repeated requests
  hashtags.forEach((tag) => INVALID_HASHTAGS.add(tag));
}

export default extension;
