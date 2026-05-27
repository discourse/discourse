const HTML_INLINE_MARKS = {
  s: "strikethrough",
  strike: "strikethrough",
  strong: "strong",
  b: "strong",
  em: "em",
  i: "em",
  code: "code",
};

const ALLOWED_INLINE = [
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

const ALLOWED_TAG_ATTRS = {
  span: ["lang"],
  ruby: ["lang"],
  rb: ["lang"],
  rt: ["lang"],
};

function extractHtmlAttrs(element, tagName) {
  const allowed = ALLOWED_TAG_ATTRS[tagName];
  if (!allowed) {
    return null;
  }
  const attrs = {};
  let hasAny = false;
  for (const attr of allowed) {
    const value = element.getAttribute(attr);
    if (value != null) {
      attrs[attr] = value;
      hasAny = true;
    }
  }
  return hasAny ? attrs : null;
}

function serializeHtmlAttrs(htmlAttrs) {
  if (!htmlAttrs) {
    return "";
  }
  return Object.entries(htmlAttrs)
    .map(
      ([k, v]) =>
        ` ${k}="${v.replace(/&/g, "&amp;").replace(/"/g, "&quot;").replace(/</g, "&lt;").replace(/>/g, "&gt;")}"`
    )
    .join("");
}

const ALL_ALLOWED_TAGS = [...Object.keys(HTML_INLINE_MARKS), ...ALLOWED_INLINE];

/** @type {RichEditorExtension} */
const extension = {
  nodeSpec: {
    html_inline: {
      group: "inline",
      inline: true,
      defining: true,
      content: "inline*",
      attrs: { tag: {}, htmlAttrs: { default: null } },
      parseDOM: ALLOWED_INLINE.map((tag) => ({
        tag,
        getAttrs: (element) => {
          if (tag === "span") {
            const htmlAttrs = extractHtmlAttrs(element, tag);
            if (!htmlAttrs) {
              return false;
            }
            return { tag, htmlAttrs };
          }
          return { tag, htmlAttrs: extractHtmlAttrs(element, tag) };
        },
      })),
      toDOM: (node) => {
        const domAttrs = node.attrs.htmlAttrs
          ? { ...node.attrs.htmlAttrs }
          : {};
        return [node.attrs.tag, domAttrs, 0];
      },
    },
  },
  parse: {
    html_inline: (state, token) => {
      const openMatch = token.content.match(/^<([a-z]+)(\s[^>]*)?\/?>$/i);
      const closeMatch = token.content.match(/^<\/([a-z]+)>$/i);

      if (openMatch) {
        const tagName = openMatch[1].toLowerCase();
        const hasAttributes = openMatch[2];

        if (tagName === "br") {
          state.addNode(state.schema.nodes.hard_break);
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

            if (ALLOWED_INLINE.includes(tagName)) {
              const htmlAttrs = extractHtmlAttrs(element, tagName);
              state.openNode(state.schema.nodes.html_inline, {
                tag: tagName,
                htmlAttrs,
              });
              return;
            }
          }
        }

        const markName = HTML_INLINE_MARKS[tagName];
        if (markName) {
          state.openMark(state.schema.marks[markName].create());
          return;
        }

        if (ALLOWED_INLINE.includes(tagName)) {
          state.openNode(state.schema.nodes.html_inline, {
            tag: tagName,
          });
        }

        return;
      }

      if (closeMatch) {
        const tagName = closeMatch[1].toLowerCase();

        if (tagName === "a") {
          state.closeMark(state.schema.marks.link);
          return;
        }

        const markName = HTML_INLINE_MARKS[tagName];
        if (markName) {
          state.closeMark(state.schema.marks[markName].create());
          return;
        }

        if (ALLOWED_INLINE.includes(tagName)) {
          state.closeNode();
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
  inputRules: {
    match: new RegExp(`<(${ALL_ALLOWED_TAGS.join("|")})>$`, "i"),
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
};

export default extension;
