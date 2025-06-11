import { mentionRegex } from "pretty-text/mentions";
import { ajax } from "discourse/lib/ajax";
import { isBoundary } from "discourse/static/prosemirror/lib/markdown-it";

const VALID_MENTIONS = new Set();
const INVALID_MENTIONS = new Set();
const PENDING_MENTIONS = new Set();

/** @type {RichEditorExtension} */
const extension = {
  nodeSpec: {
    mention: {
      attrs: { name: {}, valid: { default: true } },
      inline: true,
      group: "inline",
      draggable: true,
      selectable: false,
      parseDOM: [
        {
          tag: "a.mention",
          preserveWhitespace: "full",
          getAttrs: (dom) => {
            return {
              name: dom.getAttribute("data-name"),
              valid: dom.getAttribute("data-valid"),
            };
          },
        },
      ],
      toDOM: (node) => {
        return [
          "a",
          {
            class: "mention",
            "data-name": node.attrs.name,
            "data-valid": node.attrs.valid,
          },
          `@${node.attrs.name}`,
        ];
      },
    },
  },

  inputRules: {
    // TODO(renato): pass unicodeUsernames?
    match: new RegExp(`(^|\\W)(${mentionRegex().source}) $`),
    handler: (state, match, start, end) => {
      const { $from } = state.selection;
      if ($from.nodeBefore?.type === state.schema.nodes.mention) {
        return null;
      }
      const mentionStart = start + match[1].length;
      const name = match[2].slice(1);

      return state.tr.replaceWith(mentionStart, end, [
        state.schema.nodes.mention.create({ name }),
        state.schema.text(" "),
      ]);
    },
    options: { undoable: false },
  },

  parse: {
    mention: {
      block: "mention",
      getAttrs: (token, tokens, i) => ({
        // this is not ideal, but working around the mention_open/close structure
        // a text is expected just after the mention_open token
        name: tokens.splice(i + 1, 1)[0].content.slice(1),
      }),
    },
  },

  serializeNode: {
    mention(state, node, parent, index) {
      state.flushClose();
      if (!isBoundary(state.out, state.out.length - 1)) {
        state.write(" ");
      }

      state.write(`@${node.attrs.name}`);

      const nextSibling =
        parent.childCount > index + 1 ? parent.child(index + 1) : null;
      if (nextSibling?.isText && !isBoundary(nextSibling.text, 0)) {
        state.write(" ");
      }
    },
  },

  plugins({ pmState: { Plugin, PluginKey } }) {
    const key = new PluginKey("mention");

    return new Plugin({
      key,
      view() {
        return {
          update(view) {
            this.processMentionNodes(view);
          },
          processMentionNodes(view) {
            const nodeList = [];

            view.state.doc.descendants((node, pos) => {
              if (node.type.name !== "mention") {
                return;
              }

              const name = node.attrs.name;

              if (
                VALID_MENTIONS.has(name) ||
                INVALID_MENTIONS.has(name) ||
                PENDING_MENTIONS.has(name)
              ) {
                return;
              }
              PENDING_MENTIONS.add(name);
              nodeList.push({ node, pos });
            });

            if (!nodeList.length) {
              return;
            }

            // process in reverse to avoid issues with position shifts
            nodeList.sort((a, b) => b.pos - a.pos);

            const invalidateMentions = async () => {
              await fetchMentions([...PENDING_MENTIONS]);

              for (const item of nodeList) {
                const { node, pos } = item;
                const name = node.attrs.name;

                if (VALID_MENTIONS.has(name)) {
                  continue;
                }

                view.dispatch(
                  view.state.tr.setNodeMarkup(pos, null, {
                    ...node.attrs,
                    valid: false,
                  })
                );
              }
            };

            invalidateMentions();
          },
        };
      },
    });
  },
};

async function fetchMentions(names) {
  PENDING_MENTIONS.clear();

  names = names.filter(
    (name) => !VALID_MENTIONS.has(name) && !INVALID_MENTIONS.has(name)
  );

  if (names.length === 0) {
    return;
  }

  const response = await ajax("/composer/mentions", {
    data: { names },
  });

  names.forEach((name) => {
    if (response.users.includes(name) || response.groups[name]) {
      VALID_MENTIONS.add(name);
    } else {
      INVALID_MENTIONS.add(name);
    }
  });
}

export default extension;
