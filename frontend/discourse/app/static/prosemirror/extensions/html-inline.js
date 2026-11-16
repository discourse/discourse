import { isAllowListedAttr } from "pretty-text/sanitizer";
import { Fragment } from "prosemirror-model";
import { TextSelection } from "prosemirror-state";
import { i18n } from "discourse-i18n";
import { getAllowLister } from "../lib/markdown-it.js";

const HTML_INLINE_MARKS = {
  s: "strikethrough",
  strike: "strikethrough",
  strong: "strong",
  b: "strong",
  em: "em",
  i: "em",
  code: "code",
};

const INLINE_TAGS = [
  "kbd",
  "sup",
  "sub",
  "small",
  "big",
  "del",
  "ins",
  "mark",
  "ruby",
  "rb",
  "rt",
  "rp",
  "span",
];

// Tags with a look of their own on the element (markers and cell borders
// count, margins and link colour don't). Any other tag is outlined.
const STYLED_TAGS = [
  ...INLINE_TAGS.filter((tag) => tag !== "span"),
  "abbr",
  "blockquote",
  "dd",
  "details",
  "dl",
  "dt",
  "h1",
  "h2",
  "h3",
  "h4",
  "h5",
  "h6",
  "li",
  "ol",
  "pre",
  "summary",
  "table",
  "ul",
];

const VOID_TAGS = [
  "area",
  "base",
  "br",
  "col",
  "embed",
  "hr",
  "img",
  "input",
  "link",
  "meta",
  "param",
  "source",
  "track",
  "wbr",
];

// Tags that open an HTML block at a line start (markdown-it's `html_blocks`
// plus pre/script/style/textarea), so they are only kept inside table cells.
const HTML_BLOCK_TAGS = [
  "address",
  "article",
  "aside",
  "base",
  "basefont",
  "blockquote",
  "body",
  "caption",
  "center",
  "col",
  "colgroup",
  "dd",
  "details",
  "dialog",
  "dir",
  "div",
  "dl",
  "dt",
  "fieldset",
  "figcaption",
  "figure",
  "footer",
  "form",
  "frame",
  "frameset",
  "h1",
  "h2",
  "h3",
  "h4",
  "h5",
  "h6",
  "head",
  "header",
  "hr",
  "html",
  "iframe",
  "legend",
  "li",
  "link",
  "main",
  "menu",
  "menuitem",
  "nav",
  "noframes",
  "ol",
  "optgroup",
  "option",
  "p",
  "param",
  "pre",
  "script",
  "search",
  "section",
  "style",
  "summary",
  "table",
  "tbody",
  "td",
  "textarea",
  "tfoot",
  "th",
  "thead",
  "title",
  "tr",
  "track",
  "ul",
];

// Allow-listed by the cook, but would load media or frames in the editor.
const EMBEDDED_TAGS = ["audio", "iframe", "picture", "video"];

function insideTableCell(state) {
  return state.stack.some(({ type }) =>
    ["cell", "header_cell"].includes(type.spec.tableRole)
  );
}

function isAllowListedTag(state, tagName) {
  if (
    VOID_TAGS.includes(tagName) ||
    EMBEDDED_TAGS.includes(tagName) ||
    !getAllowLister().getAllowList().tagList[tagName]
  ) {
    return false;
  }

  return !HTML_BLOCK_TAGS.includes(tagName) || insideTableCell(state);
}

function extractHtmlAttrs(element, tagName) {
  const allowLister = getAllowLister();
  const forTag = allowLister.getAllowList().attrList[tagName];
  if (!forTag) {
    return null;
  }

  const attrs = {};
  let hasAny = false;
  for (const { name, value } of element.attributes) {
    if (
      isAllowListedAttr(forTag, name, value) ||
      allowLister.getCustom().some((fn) => fn(tagName, name, value))
    ) {
      attrs[name] = value;
      hasAny = true;
    }
  }
  return hasAny ? attrs : null;
}

function closeHtmlInline(state, tagName) {
  const { html_inline } = state.schema.nodes;
  let depth = -1;

  for (let i = state.stack.length - 1; i > 0; i--) {
    const { type, attrs } = state.stack[i];
    if (!type.isInline) {
      break;
    }
    if (type === html_inline && attrs.tag === tagName) {
      depth = i;
      break;
    }
  }

  if (depth === -1) {
    return false;
  }

  while (state.stack.length > depth) {
    state.closeNode();
  }
  return true;
}

function serializeHtmlAttrs(htmlAttrs) {
  if (!htmlAttrs) {
    return "";
  }
  return Object.entries(htmlAttrs)
    .map(([k, v]) =>
      v === ""
        ? ` ${k}`
        : ` ${k}="${v.replace(/&/g, "&amp;").replace(/"/g, "&quot;").replace(/</g, "&lt;").replace(/>/g, "&gt;")}"`
    )
    .join("");
}

const INPUT_RULE_TAGS = [...Object.keys(HTML_INLINE_MARKS), ...INLINE_TAGS];

// Pasted DOM is mostly cooked output, where the allow-list is far too wide.
// Spans are left out: publishing tools stamp `lang` on every one of them.
const DOM_PARSED_INLINE = [
  ...INLINE_TAGS.filter((tag) => tag !== "span"),
  "abbr",
];

// Only lists have no markdown form inside a cell. A selector starting with
// `ul`/`ol` would stop ProseMirror from normalizing malformed nested lists.
const DOM_PARSED_IN_CELL = ["li", "ul", "ol", "dl", "dt", "dd"];

const SMALL = "small";

function isSmall(node, schema) {
  return node.type === schema.nodes.html_inline && node.attrs.tag === SMALL;
}

function withoutSmall(fragment, schema) {
  const nodes = [];
  fragment.forEach((child) => {
    const content = child.content.size
      ? withoutSmall(child.content, schema)
      : [];

    if (isSmall(child, schema)) {
      nodes.push(...content);
    } else if (child.content.size) {
      nodes.push(child.copy(Fragment.fromArray(content)));
    } else {
      nodes.push(child);
    }
  });
  return nodes;
}

function splitTrailingWhitespace(content) {
  const main = [...content];
  const lastNode = main.at(-1);
  const trailingWhitespace = lastNode?.isText
    ? lastNode.text.match(/\s+$/)?.[0]
    : null;

  if (!trailingWhitespace) {
    return [main, []];
  }

  main.pop();
  const boundary = lastNode.nodeSize - trailingWhitespace.length;
  if (boundary > 0) {
    main.push(lastNode.cut(0, boundary));
  }

  return [main, [lastNode.cut(boundary)]];
}

/**
 * Small is offered as a text size alongside the heading levels, so it applies to
 * whole lines rather than to the selected range.
 */
function selectedLines(state) {
  const { from, to, empty, $from } = state.selection;
  const lines = [];

  if (empty) {
    for (let depth = $from.depth; depth > 0; depth--) {
      const node = $from.node(depth);
      if (node.isTextblock && !node.type.spec.code) {
        lines.push({ node, pos: $from.before(depth) });
        return lines;
      }
    }
  }

  state.doc.nodesBetween(from, to, (node, pos) => {
    if (node.isTextblock) {
      if (!node.type.spec.code) {
        lines.push({ node, pos });
      }
      return false;
    }
  });

  return lines;
}

function selectedSmallRanges(state, schema) {
  const { from, to, empty, $from } = state.selection;

  if (empty) {
    for (let depth = 1; depth <= $from.depth; depth++) {
      const node = $from.node(depth);
      if (isSmall(node, schema)) {
        return [
          {
            node,
            from: $from.before(depth),
            to: $from.after(depth),
          },
        ];
      }
    }
    return [];
  }

  const ranges = [];
  let hasContent = false;
  let allSmall = true;

  state.doc.nodesBetween(from, to, (node, pos) => {
    if (node.isBlock) {
      return true;
    }
    if (isSmall(node, schema)) {
      hasContent = true;
      ranges.push({ node, from: pos, to: pos + node.nodeSize });
      return false;
    }
    if (node.isText && !node.text.trim()) {
      return false;
    }
    hasContent = true;
    allSmall = false;
    return false;
  });

  return hasContent && allSmall ? ranges : [];
}

function containsSmall(node, schema) {
  let found = false;
  node.descendants((child) => {
    if (isSmall(child, schema)) {
      found = true;
    }
    return !found;
  });
  return found;
}

function replaceLines(state, lines, replacement, schema) {
  const tr = state.tr;

  for (const { node, pos } of lines) {
    const mappedPos = tr.mapping.map(pos);

    if (schema && node.type === schema.nodes.heading) {
      tr.setNodeMarkup(mappedPos, schema.nodes.paragraph, {});
    }

    tr.replaceWith(
      tr.mapping.map(pos + 1),
      tr.mapping.map(pos + node.nodeSize - 1),
      replacement(node)
    );
  }

  return tr;
}

function unwrapSmallRanges(state, ranges, schema) {
  const tr = state.tr;

  for (const { node, from, to } of ranges) {
    tr.replaceWith(
      tr.mapping.map(from),
      tr.mapping.map(to),
      withoutSmall(node.content, schema)
    );
  }

  return tr;
}

/** @type {RichEditorExtension} */
const extension = {
  nodeSpec: {
    html_inline: {
      group: "inline",
      inline: true,
      defining: true,
      content: "inline*",
      attrs: { tag: {}, htmlAttrs: { default: null } },
      parseDOM: [
        // Outranks the list rules so a pasted list stays inline HTML in a cell.
        {
          tag: DOM_PARSED_IN_CELL.join(","),
          priority: 60,
          context: "table_cell//|table_header_cell//",
          getAttrs: (element) => {
            const tag = element.tagName.toLowerCase();
            return { tag, htmlAttrs: extractHtmlAttrs(element, tag) };
          },
        },
        ...DOM_PARSED_INLINE.map((tag) => ({
          tag,
          getAttrs: (element) => ({
            tag,
            htmlAttrs: extractHtmlAttrs(element, tag),
          }),
        })),
      ],
      toDOM: (node) => [node.attrs.tag, { ...node.attrs.htmlAttrs }, 0],
    },
  },
  parse: {
    html_inline: (state, token) => {
      const openMatch = token.content.match(
        /^<([a-z][a-z0-9]*)(\s[^>]*)?\/?>$/i
      );
      const closeMatch = token.content.match(/^<\/([a-z][a-z0-9]*)>$/i);

      if (openMatch) {
        const tagName = openMatch[1].toLowerCase();
        const hasAttributes = openMatch[2];

        if (tagName === "br") {
          state.addNode(state.schema.nodes.hard_break);
          return;
        }

        const markName = HTML_INLINE_MARKS[tagName];
        if (markName) {
          state.openMark(state.schema.marks[markName].create());
          return;
        }

        if (hasAttributes) {
          const parser = new DOMParser();
          const doc = parser.parseFromString(token.content, "text/html");
          const element = doc.body.firstElementChild;

          if (element) {
            // Handle links by delegating to the link mark
            if (tagName === "a" && element.href) {
              const attrs = {
                href: element.getAttribute("href"),
                title: element.title || null,
              };
              state.openMark(state.schema.marks.link.create(attrs));
              return;
            }

            // Handle images by delegating to the image node (self-closing)
            if (tagName === "img" && element.src) {
              const attrs = {
                src: element.src,
                alt: element.alt || null,
                title: element.title || null,
                width: element.width || null,
                height: element.height || null,
              };
              state.addNode(state.schema.nodes.image, attrs);
              return;
            }

            if (isAllowListedTag(state, tagName)) {
              const htmlAttrs = extractHtmlAttrs(element, tagName);
              state.openNode(state.schema.nodes.html_inline, {
                tag: tagName,
                htmlAttrs,
              });
              return;
            }
          }
        }

        if (isAllowListedTag(state, tagName)) {
          state.openNode(state.schema.nodes.html_inline, {
            tag: tagName,
          });
        }

        return;
      }

      if (closeMatch) {
        const tagName = closeMatch[1].toLowerCase();

        if (closeHtmlInline(state, tagName)) {
          return;
        }

        if (tagName === "a") {
          state.closeMark(state.schema.marks.link);
          return;
        }

        const markName = HTML_INLINE_MARKS[tagName];
        if (markName) {
          state.closeMark(state.schema.marks[markName].create());
        }
      }
    },
  },
  serializeNode: {
    html_inline(state, node) {
      const attrsStr = serializeHtmlAttrs(node.attrs.htmlAttrs);
      state.write(`<${node.attrs.tag}${attrsStr}>`);
      state.renderInline(node);
      state.write(`</${node.attrs.tag}>`);
    },
  },
  plugins({ pmState: { Plugin }, pmView: { Decoration, DecorationSet } }) {
    function outlineDecorations(doc) {
      const decorations = [];
      doc.descendants((node, pos) => {
        if (node.type.name !== "html_inline") {
          return;
        }

        const { tag, htmlAttrs } = node.attrs;
        if (STYLED_TAGS.includes(tag)) {
          return;
        }

        const attrs = { class: "composer-html-inline-node" };
        if (!htmlAttrs?.title) {
          attrs.title = `<${tag}${serializeHtmlAttrs(htmlAttrs)}>`;
        }
        decorations.push(Decoration.node(pos, pos + node.nodeSize, attrs));
      });
      return DecorationSet.create(doc, decorations);
    }

    return new Plugin({
      state: {
        init: (_, state) => outlineDecorations(state.doc),
        apply: (tr, set) => (tr.docChanged ? outlineDecorations(tr.doc) : set),
      },
      props: {
        decorations(state) {
          return this.getState(state);
        },
      },
    });
  },
  inputRules: {
    match: new RegExp(`<(${INPUT_RULE_TAGS.join("|")})>$`, "i"),
    handler: (state, match, start, end) => {
      const tag = match[1];

      const markName = HTML_INLINE_MARKS[tag];

      const tr = state.tr;

      if (markName) {
        tr.delete(start, end);
        tr.insertText(" ");
        tr.addMark(start, start + 1, state.schema.marks[markName].create());
        tr.removeStoredMark(state.schema.marks[markName]);
      } else {
        tr.replaceWith(
          start,
          end,
          state.schema.nodes.html_inline.create({ tag }, [
            state.schema.text(" "),
          ])
        );

        start += 1;
      }

      tr.insertText(" ");
      tr.setSelection(
        state.selection.constructor.create(tr.doc, start, start + 1)
      );

      return tr;
    },
  },
  commands: ({ schema }) => ({
    toggleSmall: () => (state, dispatch) => {
      const smallRanges = selectedSmallRanges(state, schema);

      if (smallRanges.length) {
        dispatch?.(unwrapSmallRanges(state, smallRanges, schema));
        return true;
      }

      const lines = selectedLines(state).filter(
        ({ node }) => node.content.size > 0
      );

      if (!lines.length && state.selection.empty) {
        const [{ node, pos } = {}] = selectedLines(state);
        if (!node) {
          return false;
        }

        const text = i18n("composer.heading_level_small_text");
        const tr = state.tr;
        if (node.type === schema.nodes.heading) {
          tr.setNodeMarkup(pos, schema.nodes.paragraph, {});
        }
        tr.replaceWith(
          pos + 1,
          pos + 1,
          schema.nodes.html_inline.create({ tag: SMALL }, schema.text(text))
        );
        tr.setSelection(
          TextSelection.create(tr.doc, pos + 2, pos + 2 + text.length)
        );
        dispatch?.(tr);
        return true;
      }

      if (!lines.length) {
        return false;
      }

      const tr = replaceLines(
        state,
        lines,
        (node) => {
          const [content, trailing] = splitTrailingWhitespace(
            withoutSmall(node.content, schema)
          );
          return Fragment.fromArray([
            schema.nodes.html_inline.create({ tag: SMALL }, content),
            ...trailing,
          ]);
        },
        schema
      );

      // Keep the caret inside the wrapper, so the option reports itself as
      // active and toggles back off without needing a new selection. Absorbing
      // an inner wrapper shortens the line, hence the clamp.
      if (state.selection.empty) {
        const contentStart = tr.mapping.map(lines[0].pos) + 2;
        const wrapper = tr.doc.nodeAt(contentStart - 1);

        if (wrapper) {
          tr.setSelection(
            TextSelection.create(
              tr.doc,
              Math.min(
                state.selection.from + 1,
                contentStart + wrapper.content.size
              )
            )
          );
        }
      }

      dispatch?.(tr);
      return true;
    },

    removeSmall: () => (state, dispatch) => {
      const lines = selectedLines(state).filter(({ node }) =>
        containsSmall(node, schema)
      );

      if (!lines.length) {
        return false;
      }

      dispatch?.(
        replaceLines(state, lines, (node) => withoutSmall(node.content, schema))
      );
      return true;
    },
  }),
  state: ({ schema }, state) => ({
    inSmall: selectedSmallRanges(state, schema).length > 0,
  }),
};

export default extension;
