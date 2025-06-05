import { mentionRegex } from "pretty-text/mentions";
import User from "discourse/models/user";
import { isBoundary } from "discourse/static/prosemirror/lib/markdown-it";

const validMentions = new Set();
const invalidMentions = new Set();

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
            const name = dom.getAttribute("data-name");
            return { name };
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

  plugins({ pmState: { Plugin, PluginKey }, pmView: { DecorationSet } }) {
    const plugin = new PluginKey("mention");

    return new Plugin({
      key: plugin,
      state: {
        init() {
          return DecorationSet.empty;
        },
        apply(tr, set) {
          const meta = tr.getMeta(plugin);

          if (meta?.removeDecorations) {
            set = set.remove(meta.removeDecorations);
          }

          return set.map(tr.mapping, tr.doc);
        },
      },

      props: {
        decorations(state) {
          return this.getState(state);
        },
      },

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
              }
            });

            // process in reverse to avoid issues with position shifts
            nodeList.sort((a, b) => b.pos - a.pos);

            const invalidateMentions = async () => {
              for (const item of nodeList) {
                const { node, pos } = item;
                const name = node.attrs.name;
                const isValid = await validateMention(name);

                if (!isValid) {
                  view.dispatch(
                    view.state.tr
                      .delete(pos, pos + node.nodeSize)
                      .insertText(`@${name}`, pos)
                  );
                }
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
              if (node.type.name === "text") {
                const mentionList = getMentionsFromTextNode(node, pos);

                const processMentions = async () => {
                  for (const item of mentionList) {
                    const { name, start, end } = item;
                    const isValid = await validateMention(name);
                    let nodeData;

                    if (isValid) {
                      nodeData = view.state.schema.nodes.mention.create({
                        name,
                      });
                    } else {
                      nodeData = view.state.schema.text(`@${name}`);
                    }

                    view.dispatch(tr.replaceWith(start, end, nodeData));
                  }
                };

                processMentions();
              }
            });
          },
        };
      },
    });
  },
};

function getMentionsFromTextNode(node, pos) {
  const text = node.text;
  let match;

  const regex = new RegExp(`(^|\\W)(${mentionRegex().source})(?=\\s|$)`, "g");
  let mentionList = [];

  while ((match = regex.exec(text)) !== null) {
    const name = match[2].slice(1);

    if (invalidMentions.has(name) || validMentions.has(name)) {
      continue;
    }

    const start = pos + match.index + match[1].length;
    const end = start + match[2].length;

    mentionList.push({ name, start, end });
  }

  return mentionList;
}

async function validateMention(name) {
  if (!name || invalidMentions.has(name)) {
    return false;
  }

  if (validMentions.has(name)) {
    return true;
  }

  try {
    const valid = !!(await User.findByUsername(name));

    if (valid) {
      validMentions.add(name);
    }

    return valid;
  } catch (error) {
    // eslint-disable-next-line no-console
    console.warn("Validation failed for", name, error);
    invalidMentions.add(name);

    return false;
  }
}

export default extension;
