import { buildEmojiUrl, emojiExists, isCustomEmoji } from "pretty-text/emoji";
import { translations } from "pretty-text/emoji/data";
import { Plugin } from "prosemirror-state";
import { Decoration, DecorationSet } from "prosemirror-view";
import escapeRegExp from "discourse/lib/escape-regexp";
import { emojiOptions } from "discourse/lib/text";
import { isBoundary } from "discourse/static/prosemirror/lib/markdown-it";

/**
 * Find all paragraphs in the document
 * @param {Object} doc - ProseMirror document
 * @returns {Array} Array of paragraph ranges (start, end)
 */
function findParagraphs(doc) {
  const ranges = [];
  doc.forEach((node, offset) => {
    ranges.push({ start: offset, end: offset + node.nodeSize });
  });
  return ranges;
}

/**
 * Checks if a paragraph contains only emojis
 * @param {Object} doc - ProseMirror document
 * @param {number} start - Start position of the paragraph
 * @param {number} end - End position of the paragraph
 * @returns {boolean} True if the paragraph contains only emojis and has 3 or fewer
 */
function hasOnlyEmojis(doc, start, end) {
  let emojiCount = 0;
  let hasNonEmptyText = false;

  // Process all content between start and end
  doc.nodesBetween(start, end, (node) => {
    if (node.type.name === "emoji") {
      emojiCount++;
    } else if (node.type.name === "text") {
      // Check if text has actual content (ignoring whitespace)
      if (node.text && node.text.trim().length > 0) {
        hasNonEmptyText = true;
        return false; // Stop traversal once we find non-whitespace text
      }
    } else if (node.type.name !== "paragraph" && node.type.name !== "doc") {
      // Any other node type means this isn't an emoji-only paragraph
      hasNonEmptyText = true;
      return false;
    }

    return true;
  });

  return emojiCount > 0 && emojiCount <= 3 && !hasNonEmptyText;
}

/**
 * Creates decorations for specific paragraphs in the document
 * @param {Object} doc - ProseMirror document
 * @param {Array} paragraphRanges - Array of paragraph ranges to check
 * @param {DecorationSet} oldSet - Previous decoration set
 * @returns {DecorationSet} Updated decoration set
 */
function updateParagraphDecorations(doc, paragraphRanges, oldSet) {
  let newSet = oldSet;

  paragraphRanges.forEach(({ start, end }) => {
    // Remove old decorations in this range
    newSet = newSet.remove(newSet.find(start, end));

    if (hasOnlyEmojis(doc, start, end)) {
      const newDecorations = [];

      // Add the only-emoji class to all emojis in this paragraph
      doc.nodesBetween(start, end, (node, pos) => {
        if (node.type.name === "emoji") {
          newDecorations.push(
            Decoration.node(pos, pos + node.nodeSize, {
              class: "only-emoji",
            })
          );
        }
      });

      if (newDecorations.length > 0) {
        newSet = newSet.add(doc, newDecorations);
      }
    }
  });

  return newSet;
}

/**
 * Find the paragraph affected by a transaction
 * @param {Transaction} tr - The transaction
 * @returns {Array} Array of paragraph ranges
 */
function findAffectedParagraphs(tr) {
  if (!tr.steps.length) {
    return [];
  }

  const from = tr.steps[0].from;
  if (!from) {
    return [];
  }

  const pos = tr.doc.resolve(tr.mapping.map(from));
  for (let d = pos.depth; d >= 0; d--) {
    if (pos.node(d).isBlock) {
      return [{ start: pos.start(d), end: pos.end(d) }];
    }
  }

  return [];
}

/**
 * Creates decorations for the entire document
 * @param {Object} doc - ProseMirror document
 * @returns {DecorationSet} Set of decorations
 */
function createDecorations(doc) {
  const paragraphs = findParagraphs(doc);
  const decorations = [];

  paragraphs.forEach(({ start, end }) => {
    if (hasOnlyEmojis(doc, start, end)) {
      // Add the only-emoji class to all emojis in this paragraph
      doc.nodesBetween(start, end, (node, pos) => {
        if (node.type.name === "emoji") {
          decorations.push(
            Decoration.node(pos, pos + node.nodeSize, {
              class: "only-emoji",
            })
          );
        }
      });
    }
  });

  return DecorationSet.create(doc, decorations);
}

/**
 * Plugin that adds the only-emoji class to emojis
 * @returns {Plugin} ProseMirror plugin
 */
function createOnlyEmojiPlugin() {
  return new Plugin({
    state: {
      init(_, instance) {
        return createDecorations(instance.doc);
      },
      apply(tr, value) {
        if (!tr.docChanged) {
          return value;
        }

        const affectedParagraphs = findAffectedParagraphs(tr);
        // If we couldn't identify specific paragraphs, update the entire document
        if (affectedParagraphs.length === 0) {
          return createDecorations(tr.doc);
        }

        return updateParagraphDecorations(
          tr.doc,
          affectedParagraphs,
          value.map(tr.mapping, tr.doc)
        );
      },
    },
    props: {
      decorations(state) {
        return this.getState(state);
      },
    },
  });
}

/** @type {RichEditorExtension} */
const extension = {
  nodeSpec: {
    emoji: {
      attrs: { code: {} },
      inline: true,
      group: "inline",
      draggable: true,
      selectable: false,
      parseDOM: [
        {
          tag: "img.emoji",
          getAttrs: (dom) => {
            return { code: dom.getAttribute("alt").replace(/:/g, "") };
          },
          priority: 60,
        },
      ],
      toDOM: (node) => {
        const opts = emojiOptions();
        const code = node.attrs.code.toLowerCase();
        const title = `:${code}:`;
        const src = buildEmojiUrl(code, opts);

        return [
          "img",
          {
            class: isCustomEmoji(code, opts) ? "emoji emoji-custom" : "emoji",
            alt: title,
            title,
            src,
          },
        ];
      },
    },
  },

  inputRules: [
    {
      match: /(^|\W):([^:]+):$/,
      handler: (state, match, start, end) => {
        if (emojiExists(match[2])) {
          const emojiStart = start + match[1].length;
          return state.tr.replaceWith(
            emojiStart,
            end,
            state.schema.nodes.emoji.create({ code: match[2] })
          );
        }
      },
      options: { undoable: false },
    },
    {
      match: new RegExp(
        "(^|\\W)(" +
          Object.keys(translations).map(escapeRegExp).join("|") +
          ") $"
      ),
      handler: (state, match, start, end) => {
        const emojiStart = start + match[1].length;
        return state.tr
          .replaceWith(
            emojiStart,
            end,
            state.schema.nodes.emoji.create({ code: translations[match[2]] })
          )
          .insertText(" ");
      },
    },
  ],

  parse: {
    emoji: {
      node: "emoji",
      getAttrs: (token) => ({
        code: token.attrGet("alt").slice(1, -1),
      }),
    },
  },

  serializeNode: {
    emoji(state, node) {
      if (!isBoundary(state.out, state.out.length - 1)) {
        state.write(" ");
      }

      state.write(`:${node.attrs.code}:`);
    },
  },

  plugins: () => [createOnlyEmojiPlugin()],
};

export default extension;
