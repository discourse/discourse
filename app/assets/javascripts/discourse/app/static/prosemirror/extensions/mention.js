import { mentionRegex } from "pretty-text/mentions";
import { ajax } from "discourse/lib/ajax";
import { isBoundary } from "discourse/static/prosemirror/lib/markdown-it";

const VALID_MENTIONS = new Set();
const INVALID_MENTIONS = new Set();
const PENDING_MENTIONS = new Set();
const MENTION_REGEXP = new RegExp(
  `(^|\\W)(${mentionRegex().source})(?=\\s|$)`,
  "g"
);

/** @type {RichEditorExtension} */
const extension = {
  nodeSpec: {
    mention: {
      attrs: { name: {} },
      inline: true,
      group: "inline",
      draggable: true,
      selectable: false,
      parseDOM: [
        {
          tag: "a.mention",
          preserveWhitespace: "full",
          getAttrs: (dom) => {
            return { name: dom.getAttribute("data-name") };
          },
        },
      ],
      toDOM: (node) => {
        return [
          "a",
          { class: "mention", "data-name": node.attrs.name },
          `@${node.attrs.name}`,
        ];
      },
    },
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
    const plugin = new PluginKey("mention");

    return new Plugin({
      key: plugin,
      view() {
        return {
          update(view) {
            if (!view._existingMentionsValidated) {
              this.processExistingMentions(view);
              view._existingMentionsValidated = true;
            }

            this.processNewMentions(view);
          },
          processExistingMentions(view) {
            const nodeList = [];

            view.state.doc.descendants((node, pos) => {
              if (node.type.name === "mention") {
                nodeList.push({ node, pos });
                PENDING_MENTIONS.add(node.attrs.name);
              }
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
                  view.state.tr
                    .delete(pos, pos + node.nodeSize)
                    .insertText(`@${name}`, pos)
                );
              }
            };

            invalidateMentions();
          },
          processNewMentions(view) {
            const tr = view.state.tr;

            if (!isBoundary(tr.doc.textContent.slice(-1), 0)) {
              return;
            }

            view.state.doc.descendants((node, pos) => {
              if (node.type.name !== "text") {
                return;
              }

              const mentionList = getMentionsFromTextNode(node, pos);

              if (!mentionList.length) {
                return;
              }

              const processMentions = async () => {
                await fetchMentions([...PENDING_MENTIONS]);

                for (const item of mentionList) {
                  const { name, start, end } = item;

                  if (!VALID_MENTIONS.has(name)) {
                    continue;
                  }

                  view.dispatch(
                    tr.replaceWith(
                      start,
                      end,
                      view.state.schema.nodes.mention.create({
                        name,
                      })
                    )
                  );
                }
              };

              processMentions();
            });
          },
        };
      },
    });
  },
};

function getMentionsFromTextNode(node, pos) {
  let mentionList = [];
  let match;

  while ((match = MENTION_REGEXP.exec(node.text)) !== null) {
    const name = match[2].slice(1);

    if (VALID_MENTIONS.has(name) || INVALID_MENTIONS.has(name)) {
      continue;
    } else if (!PENDING_MENTIONS.has(name)) {
      PENDING_MENTIONS.add(name);
    }

    const start = pos + match.index + match[1].length;
    const end = start + match[2].length;

    mentionList.push({ name, start, end });
  }

  return mentionList;
}

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
