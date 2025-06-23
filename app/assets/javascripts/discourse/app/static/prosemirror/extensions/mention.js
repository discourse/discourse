import { mentionRegex } from "pretty-text/mentions";
import { ajax } from "discourse/lib/ajax";
import { isBoundary } from "discourse/static/prosemirror/lib/markdown-it";

const VALID_MENTIONS = new Set();
const INVALID_MENTIONS = new Set();

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
            const mentionNames = [];
            const mentionNodes = [];

            if (this._processingMentionNodes) {
              return;
            }

            this._processingMentionNodes = true;

            view.state.doc.descendants((node, pos) => {
              if (node.type.name !== "mention" || !node.attrs.valid) {
                return;
              }

              const name = node.attrs.name;
              mentionNames.push(name);
              mentionNodes.push({ name, node, pos });
            });

            // process in reverse to avoid issues with position shifts
            mentionNodes.sort((a, b) => b.pos - a.pos);

            const invalidateMentions = async () => {
              await fetchMentions(mentionNames);

              for (const mentionNode of mentionNodes) {
                const { name, node, pos } = mentionNode;

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

            invalidateMentions().then(() => {
              this._processingMentionNodes = false;
            });
          },
        };
      },
    });
  },
};

async function fetchMentions(names) {
  // only fetch new mentions that are not already validated
  names = names.uniq().filter((name) => {
    return !VALID_MENTIONS.has(name) && !INVALID_MENTIONS.has(name);
  });

  if (!names.length) {
    return;
  }

  const response = await ajax("/composer/mentions", {
    data: { names },
  });

  const lowerGroupNames = Object.keys(response.groups).map((groupName) =>
    groupName.toLowerCase()
  );

  names.forEach((name) => {
    const lowerName = name.toLowerCase();

    if (
      response.users.includes(lowerName) ||
      lowerGroupNames.includes(lowerName)
    ) {
      VALID_MENTIONS.add(name);
    } else {
      INVALID_MENTIONS.add(name);
    }
  });
}

export default extension;
