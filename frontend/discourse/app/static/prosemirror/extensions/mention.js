import { mentionRegex } from "pretty-text/mentions";
import { ajax } from "discourse/lib/ajax";
import { uniqueItemsFromArray } from "discourse/lib/array-tools";
import getURL from "discourse/lib/get-url";
import { isBoundary } from "discourse/static/prosemirror/lib/markdown-it";
import { i18n } from "discourse-i18n";

const VALID_MENTIONS = new Set();
const INVALID_MENTIONS = new Set();

function unicodeEnabled({ getContext }) {
  return getContext().siteSettings.unicodeUsernames;
}

const resolvedMentionRegex = mentionRegex(unicodeEnabled);

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
          priority: 60,
          tag: "a.mention",
          preserveWhitespace: "full",
          getAttrs: (dom) => {
            return {
              name: dom.getAttribute("data-name") ?? dom.textContent.slice(1),
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
          },
          `@${node.attrs.name}`,
        ];
      },
    },
  },
  inputRules: {
    match: new RegExp(
      `(^|\\W)(${resolvedMentionRegex.source}) $`,
      `${resolvedMentionRegex.flags}`
    ),
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

  plugins({ pmState: { Plugin, PluginKey }, getContext }) {
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
            const hereMention = getContext().siteSettings.here_mention;

            if (this._processingMentionNodes) {
              return;
            }

            this._processingMentionNodes = true;

            view.state.doc.descendants((node, pos) => {
              if (node.type.name !== "mention") {
                return;
              }

              const name = node.attrs.name;
              mentionNames.push(name);
              mentionNodes.push({ name, node, pos });
            });

            // process in reverse to avoid issues with position shifts
            mentionNodes.sort((a, b) => b.pos - a.pos);

            const invalidateMentions = async () => {
              await fetchMentions(mentionNames, getContext());

              for (const mentionNode of mentionNodes) {
                const { name, node, pos } = mentionNode;

                if (VALID_MENTIONS.has(name) || hereMention === name) {
                  continue;
                }

                // insert invalid mentions as text nodes
                const textNode = view.state.schema.text(`@${name}`);
                view.dispatch(
                  view.state.tr.replaceWith(pos, pos + node.nodeSize, textNode)
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

async function fetchMentions(names, context) {
  // only fetch new mentions that are not already validated
  names = uniqueItemsFromArray(names).filter((name) => {
    return !VALID_MENTIONS.has(name) && !INVALID_MENTIONS.has(name);
  });

  if (!names.length) {
    return;
  }

  const response = await ajax("/composer/mentions", {
    data: { names, topic_id: context.topicId },
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

    checkMentionWarning(name, response, context);
  });
}

function checkMentionWarning(name, response, context) {
  const hereCount = parseInt(response?.here_count, 10) || 0;
  const maxMentions = parseInt(
    response?.max_users_notified_per_group_mention,
    10
  );

  let reason;
  let body;

  if (hereCount > 0) {
    body = i18n(`composer.here_mention`, {
      here: context.siteSettings.here_mention,
      count: hereCount,
    });
  } else if (response.users.includes(name)) {
    reason = response.user_reasons?.[name];

    if (reason) {
      body = i18n(`composer.cannot_see_mention.${reason}`, {
        username: name,
      });
    }
  } else if (response.groups[name]) {
    const userCount = response.groups[name]?.user_count || 0;
    const notifiedCount = response.groups[name]?.notified_count || 0;
    reason = response.group_reasons?.[name];

    const groupLink = getURL(`/g/${name}/members`);

    if (reason) {
      body = i18n(`composer.cannot_see_group_mention.${reason}`, {
        group: name,
        count: notifiedCount,
      });
    } else if (notifiedCount > maxMentions) {
      body = i18n("composer.group_mentioned_limit", {
        group: `@${name}`,
        count: maxMentions,
        group_link: groupLink,
      });
    } else if (userCount > 0) {
      const translationKey =
        userCount >= 5
          ? "composer.larger_group_mentioned"
          : "composer.group_mentioned";

      body = i18n(translationKey, {
        group: `@${name}`,
        count: userCount,
        group_link: groupLink,
      });
    }
  }

  if (body) {
    context.appEvents.trigger("composer-messages:create", {
      extraClass: "custom-body",
      templateName: "education",
      body,
    });
  }
}

export default extension;
