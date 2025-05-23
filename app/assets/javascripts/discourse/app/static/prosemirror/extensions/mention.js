import { mentionRegex } from "pretty-text/mentions";
import User from "discourse/models/user";
import { isBoundary } from "discourse/static/prosemirror/lib/markdown-it";
import { getChangedRanges } from "discourse/static/prosemirror/lib/plugin-utils";

const invalidUsernames = new Set();

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

  plugins({
    pmState: { Plugin, PluginKey },
    pmView: { Decoration, DecorationSet },
  }) {
    const plugin = new PluginKey("mention");

    function findMentionsInNode(node, pos) {
      if (!node.isText) {
        return [];
      }

      const decorations = [];
      const text = node.text;
      let match;

      const regex = new RegExp(
        `(^|\\W)(${mentionRegex().source})(?=\\s|$)`,
        "g"
      );

      while ((match = regex.exec(text)) !== null) {
        const name = match[2].slice(1);
        const start = pos + match.index + match[1].length;
        const end = start + match[2].length;

        if (invalidUsernames.has(name)) {
          continue;
        }

        // Create the decoration to mark where we'll replace with a mention
        // The decoration will be replaced completely during the validation process
        decorations.push(
          Decoration.inline(start, end, {
            class: "mention-loading",
            nodeName: "span",
            "data-name": name,
          })
        );
      }

      return decorations;
    }

    const mentionPlugin = new Plugin({
      key: plugin,
      state: {
        init() {
          return DecorationSet.empty;
        },
        apply(tr, set, oldState, newState) {
          const meta = tr.getMeta(plugin);

          if (meta?.removeDecorations) {
            set = set.remove(meta.removeDecorations);
          }

          set = set.map(tr.mapping, tr.doc);

          if (!isBoundary(tr.doc.textContent.slice(-1), 0)) {
            return set;
          }

          const changedRanges = getChangedRanges(tr);

          changedRanges.forEach(({ new: { from, to } }) => {
            const decorations = [];

            newState.doc.nodesBetween(from, to, (node, pos) => {
              const newDecorations = findMentionsInNode(node, pos);
              decorations.push(...newDecorations);
              return true;
            });

            if (decorations.length > 0) {
              set = set.add(newState.doc, decorations);
            }
          });

          return set;
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
            const decorations = plugin.getState(view.state);

            let pendingDecorations = [];
            let removeDecorations = [];
            let pendingChanges = [];

            function traverseDecorationSet(decorSet) {
              if (decorSet.local) {
                decorSet.local.forEach((decoration) => {
                  if (decoration.type?.attrs?.class === "mention-loading") {
                    pendingDecorations.push(decoration);
                  }
                });
              }

              // Check children (recursively)
              // DecorationSet children are structured as [start, end, child, start, end, child, ...]
              if (decorSet.children) {
                for (let i = 2; i < decorSet.children.length; i += 3) {
                  if (decorSet.children[i]) {
                    traverseDecorationSet(decorSet.children[i]);
                  }
                }
              }
            }

            traverseDecorationSet(decorations);

            if (view._processingMentions) {
              return;
            }

            if (pendingDecorations.length === 0) {
              return;
            }

            view._processingMentions = true;

            const processMentions = async () => {
              try {
                for (const decoration of pendingDecorations) {
                  const from = decoration.from + 1;
                  const to = decoration.to + 1;
                  const text = view.state.doc.textBetween(from, to);

                  if (!text) {
                    removeDecorations.push(decoration);
                    continue;
                  }

                  const username = decoration.type?.attrs?.["data-name"];

                  if (!username || invalidUsernames.has(username)) {
                    removeDecorations.push(decoration);
                    continue;
                  }

                  try {
                    const isValid = await validateMention(username);

                    // creates a mention node directly at the decoration position
                    // completely replaces the span.mention-loading element
                    if (isValid) {
                      pendingChanges.push({
                        type: "replace",
                        from,
                        to,
                        node: view.state.schema.nodes.mention.create({
                          name: username,
                        }),
                      });
                    } else {
                      // replaces invalid mentions with plain text
                      pendingChanges.push({
                        type: "replace",
                        from,
                        to,
                        node: view.state.schema.text(text),
                      });
                    }
                  } catch (error) {
                    // eslint-disable-next-line no-console
                    console.warn("[mention] Error validating mention:", error);
                  } finally {
                    removeDecorations.push(decoration);
                  }
                }

                const tr = view.state.tr;

                if (pendingChanges.length) {
                  pendingChanges.forEach((change) => {
                    if (change.type === "replace") {
                      tr.replaceWith(change.from, change.to, change.node);
                    }
                  });
                }

                if (removeDecorations.length) {
                  tr.setMeta(plugin, { removeDecorations });
                  removeDecorations = [];
                }

                view.dispatch(tr);
              } finally {
                view._processingMentions = false;
              }
            };

            processMentions();
          },
        };
      },
    });

    return mentionPlugin;
  },
};

async function checkUserExists(username) {
  if (!username || username.length < 1 || invalidUsernames.has(username)) {
    return { exists: false };
  }

  try {
    const user = await User.findByUsername(username);
    if (user) {
      return { exists: true };
    }
  } catch (error) {
    invalidUsernames.add(username);
    return { exists: false, error };
  }
}

async function validateMention(name) {
  const result = await checkUserExists(name);
  return result.exists;
}

export default extension;
