const MSO_LIST_CLASSES = [
  "MsoListParagraphCxSpFirst",
  "MsoListParagraphCxSpMiddle",
  "MsoListParagraphCxSpLast",
];

let tagDecorateCallbacks = [];
let blockDecorateCallbacks = [];
let textDecorateCallbacks = [];

/**
 * Allows to add support for custom inline markdown/bbcode prefixes
 * to convert nodes back to bbcode.
 *
 * ```
 * addTagDecorateCallback(function (text) {
 *   if (this.element.attributes.class === "loud") {
 *     this.prefix = "^^";
 *     this.suffix = "^^";
 *     return text.toLowerCase();
 *   }
 * });
 * ```
 */
export function addTagDecorateCallback(callback) {
  tagDecorateCallbacks.push(callback);
}

export function clearTagDecorateCallbacks() {
  tagDecorateCallbacks = [];
}

/**
 * Allows to add support for custom block markdown/bbcode prefixes
 * to convert nodes back to bbcode.
 *
 * ```
 * addBlockDecorateCallback(function (text) {
 *   if (this.element.attributes.class === "spoiled") {
 *     this.prefix = "[spoiler]";
 *     this.suffix = "[/spoiler]";
 *   }
 * });
 * ```
 */
export function addBlockDecorateCallback(callback) {
  blockDecorateCallbacks.push(callback);
}

export function clearBlockDecorateCallbacks() {
  blockDecorateCallbacks = [];
}

/**
 * Allows to add support for custom text node transformations
 * based on the next/previous elements.
 *
 * ```
 * addTextDecorateCallback(function (text, nextElement, previousElement) {
 *   if (
 *     startRangeOpts &&
 *     nextElement?.attributes.class?.includes("discourse-local-date") &&
 *     text === "→"
 *   ) {
 *     return "";
 *   }
 * });
 * ```
 */
export function addTextDecorateCallback(callback) {
  textDecorateCallbacks.push(callback);
}

export function clearTextDecorateCallbacks() {
  textDecorateCallbacks = [];
}

export class Tag {
  static named(name) {
    const klass = class NamedTag extends Tag {};
    klass.tagName = name;
    return klass;
  }

  static blocks() {
    return [
      "address",
      "article",
      "dd",
      "dl",
      "dt",
      "fieldset",
      "figcaption",
      "figure",
      "footer",
      "form",
      "header",
      "hgroup",
      "hr",
      "main",
      "nav",
      "p",
      "pre",
      "section",
    ];
  }

  static headings() {
    return ["h1", "h2", "h3", "h4", "h5", "h6"];
  }

  static emphases() {
    return [
      ["b", "**"],
      ["strong", "**"],
      ["i", "*"],
      ["em", "*"],
      ["s", "~~"],
      ["strike", "~~"],
    ];
  }

  static slices() {
    return ["dt", "dd", "thead", "tbody", "tfoot"];
  }

  static trimmable() {
    return [
      ...Tag.blocks(),
      ...Tag.headings(),
      ...Tag.slices(),
      "aside",
      "li",
      "td",
      "th",
      "br",
      "hr",
      "blockquote",
      "table",
      "ol",
      "tr",
      "ul",
    ];
  }

  static allowedTags() {
    return [
      "ins",
      "del",
      "small",
      "big",
      "kbd",
      "ruby",
      "rt",
      "rb",
      "rp",
      "mark",
    ];
  }

  static block(name, prefix, suffix) {
    return class extends Tag.named(name) {
      constructor() {
        super(prefix, suffix);
        this.gap = "\n\n";
      }

      decorate(text) {
        const parent = this.element.parent;

        for (const callback of blockDecorateCallbacks) {
          const result = callback.call(this, text);

          if (typeof result !== "undefined") {
            text = result;
          }
        }

        if (name === "p" && parent?.name === "li") {
          // fix for google docs
          this.gap = "";
        }

        return `${this.gap}${this.prefix}${text}${this.suffix}${this.gap}`;
      }
    };
  }

  static div() {
    return class extends Tag.block("div") {
      constructor() {
        super();
      }

      decorate(text) {
        const attr = this.element.attributes;

        if (/\bmathjax-math\b/.test(attr.class)) {
          return "";
        }

        if (/\bmath\b/.test(attr.class) && attr["data-applied-mathjax"]) {
          return "\n$$\n" + text + "\n$$\n";
        }

        return super.decorate(text);
      }
    };
  }

  static aside() {
    return class extends Tag.block("aside") {
      constructor() {
        super();
      }

      toMarkdown() {
        if (!/\bquote\b/.test(this.element.attributes.class)) {
          return super.toMarkdown();
        }

        const blockquote = this.element.children.find(
          (child) => child.name === "blockquote"
        );

        if (!blockquote) {
          return super.toMarkdown();
        }

        let text = Element.parse([blockquote], this.element) || "";
        text = text.trim().replaceAll(/^> /gm, "").trim();
        if (text.length === 0) {
          return "";
        }

        const username = this.element.attributes["data-username"];
        const post = this.element.attributes["data-post"];
        const topic = this.element.attributes["data-topic"];

        const prefix =
          username && post && topic
            ? `[quote="${username}, post:${post}, topic:${topic}"]`
            : "[quote]";

        return `\n${prefix}\n${text}\n[/quote]\n`;
      }
    };
  }

  static heading(name, i) {
    const prefix = `${[...Array(i)].map(() => "#").join("")} `;
    return Tag.block(name, prefix, "");
  }

  static emphasis(name, decorator) {
    return class extends Tag.named(name) {
      constructor() {
        super(decorator, decorator, true);
      }

      decorate(text) {
        if (text.includes("\n")) {
          this.prefix = `<${name}>`;
          this.suffix = `</${name}>`;
        }

        let space = text.match(/^\s/);
        if (space) {
          this.prefix = space[0] + this.prefix;
        }

        space = text.match(/\s$/);
        if (space) {
          this.suffix = this.suffix + space[0];
        }

        return super.decorate(text.trim());
      }
    };
  }

  static allowedTag(name) {
    return class extends Tag.named(name) {
      constructor() {
        super(`<${name}>`, `</${name}>`);
      }
    };
  }

  static replace(name, text) {
    return class extends Tag.named(name) {
      constructor() {
        super("", "");
        this.text = text;
      }

      toMarkdown() {
        return this.text;
      }
    };
  }

  static span() {
    return class extends Tag.named("span") {
      constructor() {
        super();
      }

      decorate(text) {
        const attr = this.element.attributes;

        if (attr.class === "badge badge-notification clicks") {
          return "";
        }

        if (/\bmathjax-math\b/.test(attr.class)) {
          return "";
        }

        if (/\bmath\b/.test(attr.class) && attr["data-applied-mathjax"]) {
          return "$" + text + "$";
        }

        return super.decorate(text);
      }
    };
  }

  static link() {
    return class extends Tag.named("a") {
      constructor() {
        super("", "", true);
      }

      decorate(text) {
        const e = this.element;
        const attr = e.attributes;

        if (/^mention/.test(attr.class) && "@" === text[0]) {
          return text;
        }

        if ("hashtag" === attr.class && "#" === text[0]) {
          return text;
        }

        if (attr.class?.includes("hashtag-cooked")) {
          if (attr["data-ref"]) {
            return `#${attr["data-ref"]}`;
          } else {
            let type = "";
            if (attr["data-type"]) {
              type = `::${attr["data-type"]}`;
            }
            return `#${attr["data-slug"]}${type}`;
          }
        }

        let img;
        if (
          ["lightbox", "d-lazyload"].includes(attr.class) &&
          (img = (e.children || []).find((c) => c.name === "img"))
        ) {
          let href = attr.href;
          const base62SHA1 = img.attributes["data-base62-sha1"];
          text = attr.title || "";

          if (base62SHA1) {
            href = `upload://${base62SHA1}`;
          }

          return `![${text}](${href})`;
        }

        if (attr.href && text !== attr.href) {
          text = text.replace(/\n{2,}/g, "\n");

          let linkModifier = "";
          if (attr.class?.includes("attachment")) {
            linkModifier = "|attachment";
          }

          return `[${text}${linkModifier}](${attr.href})`;
        }

        return text;
      }
    };
  }

  static image() {
    return class extends Tag.named("img") {
      constructor() {
        super("", "", true);
      }

      toMarkdown() {
        const e = this.element;
        const attr = e.attributes;
        const pAttr = e.parent?.attributes || {};
        const cssClass = attr.class || pAttr.class;

        let src = attr.src || pAttr.src;

        const base62SHA1 = attr["data-base62-sha1"];
        if (base62SHA1) {
          src = `upload://${base62SHA1}`;
        }

        if (cssClass?.includes("emoji")) {
          if (cssClass.includes("user-status")) {
            return "";
          }

          return attr.title || pAttr.title;
        }

        if (src) {
          if (src.match(/^data:image\/([a-zA-Z]*);base64,([^\"]*)$/)) {
            return "[image]";
          }

          let alt = attr.alt || pAttr.alt || "";
          const width = attr.width || pAttr.width;
          const height = attr.height || pAttr.height;
          const title = attr.title;

          if (width && height) {
            const pipe = this.element.parentNames.includes("table")
              ? "\\|"
              : "|";
            alt = `${alt}${pipe}${width}x${height}`;
          }

          return `![${alt}](${src}${title ? ` "${title}"` : ""})`;
        }

        return "";
      }
    };
  }

  static slice(name, suffix) {
    return class extends Tag.named(name) {
      constructor() {
        super("", suffix);
      }

      decorate(text) {
        if (!this.element.next) {
          this.suffix = "";
        }
        return `${text}${this.suffix}`;
      }
    };
  }

  static cell(name) {
    return class extends Tag.named(name) {
      constructor() {
        super("|");
      }

      toMarkdown() {
        const text = this.element.innerMarkdown().trim();

        if (text.includes("\n")) {
          // Unsupported format inside Markdown table cells
          let e = this.element;
          while ((e = e.parent)) {
            if (e.name === "table") {
              e.tag().invalid();
              break;
            }
          }
        }

        return this.decorate(text);
      }
    };
  }

  static li() {
    return class extends Tag.slice("li", "\n") {
      decorate(text) {
        const attrs = this.element.attributes;
        let indent = this.element
          .filterParentNames(["ol", "ul"])
          .slice(1)
          .map(() => "\t")
          .join("");

        if (MSO_LIST_CLASSES.includes(attrs.class)) {
          try {
            const level = parseInt(
              attrs.style.match(/level./)[0].replace("level", ""),
              10
            );
            indent = Array(level).join("\t") + indent;
          } finally {
            if (attrs.class === "MsoListParagraphCxSpFirst") {
              indent = `\n\n${indent}`;
            } else if (attrs.class === "MsoListParagraphCxSpLast") {
              text = `${text}\n`;
            }
          }
        }

        return super.decorate(`${indent}* ${text.trimStart()}`);
      }
    };
  }

  static code() {
    return class extends Tag.named("code") {
      constructor() {
        super("`", "`");
      }

      decorate(text) {
        if (this.element.parentNames.includes("pre")) {
          this.prefix = "\n\n```\n";
          this.suffix = "\n```\n\n";
        } else {
          this.inline = true;
        }

        const textarea = document.createElement("textarea");
        textarea.innerHTML = text;
        return super.decorate(textarea.innerText);
      }
    };
  }

  static blockquote() {
    return class extends Tag.named("blockquote") {
      constructor() {
        super("\n> ", "\n");
      }

      decorate(text) {
        text = text
          .trim()
          .replace(/\n{2,}>/g, "\n>")
          .replace(/\n/g, "\n> ");
        return super.decorate(text);
      }
    };
  }

  static table() {
    return class extends Tag.block("table") {
      constructor() {
        super();
        this.isValid = true;
      }

      invalid() {
        this.isValid = false;
        if (this.element.parentNames.includes("table")) {
          let e = this.element;
          while ((e = e.parent)) {
            if (e.name === "table") {
              e.tag().invalid();
              break;
            }
          }
        }
      }

      countPipes(text) {
        return (text.replace(/\\\|/, "").match(/\|/g) || []).length;
      }

      decorate(text) {
        text = super.decorate(text).replace(/\|\n{2,}\|/g, "|\n|");
        const rows = text.trim().split("\n");
        const pipeCount = this.countPipes(rows[0]);
        this.isValid =
          this.isValid &&
          rows.length > 1 &&
          pipeCount > 2 &&
          rows.reduce((a, c) => a && this.countPipes(c) <= pipeCount); // Unsupported table format for Markdown conversion

        if (this.isValid) {
          const splitterRow =
            [...Array(pipeCount - 1)].map(() => "| --- ").join("") + "|\n";
          text = text.replace("|\n", "|\n" + splitterRow);
        } else {
          text = text.replace(/\|/g, " ");
          this.invalid();
        }

        return text;
      }
    };
  }

  static list(name) {
    return class extends Tag.block(name) {
      decorate(text) {
        let smallGap = "";
        const parent = this.element.parent;

        if (parent?.name === "ul") {
          this.gap = "";
          this.suffix = "\n";
        }

        if (this.element.filterParentNames(["li"]).length) {
          this.gap = "";
          smallGap = "\n";
        }

        return smallGap + super.decorate(text.trimEnd());
      }
    };
  }

  static ol() {
    return class extends Tag.list("ol") {
      decorate(text) {
        text = "\n" + text;
        const bullet = text.match(/\n\t*\*/)[0];
        let i = parseInt(this.element.attributes.start || 1, 10);

        while (text.includes(bullet)) {
          text = text.replace(bullet, bullet.replace("*", `${i}.`));
          i++;
        }

        return super.decorate(text.slice(1));
      }
    };
  }

  static tr() {
    return class extends Tag.slice("tr", "|\n") {
      decorate(text) {
        if (!this.element.next) {
          this.suffix = "|";
        }
        return `${text}${this.suffix}`;
      }
    };
  }

  constructor(prefix = "", suffix = "", inline = false) {
    this.prefix = prefix;
    this.suffix = suffix;
    this.inline = inline;
  }

  decorate(text) {
    for (const callback of tagDecorateCallbacks) {
      const result = callback.call(this, text);

      if (typeof result !== "undefined") {
        text = result;
      }
    }

    if (this.prefix || this.suffix) {
      text = [this.prefix, text, this.suffix].join("");
    }

    if (this.inline) {
      const { prev, next } = this.element;

      if (prev && prev.name !== "#text") {
        text = " " + text;
      }

      if (next && next.name !== "#text") {
        text = text + " ";
      }
    }

    return text;
  }

  toMarkdown() {
    const text = this.element.innerMarkdown();

    if (text?.trim()) {
      return this.decorate(text);
    }

    return text;
  }
}

let tagsMap;

function tagByName(name) {
  if (!tagsMap) {
    tagsMap = new Map();

    const allTags = [
      ...Tag.blocks().map((b) => Tag.block(b)),
      ...Tag.headings().map((h, i) => Tag.heading(h, i + 1)),
      ...Tag.slices().map((s) => Tag.slice(s, "\n")),
      ...Tag.emphases().map((e) => Tag.emphasis(e[0], e[1])),
      ...Tag.allowedTags().map((t) => Tag.allowedTag(t)),
      Tag.aside(),
      Tag.cell("td"),
      Tag.cell("th"),
      Tag.replace("br", "\n"),
      Tag.replace("hr", "\n---\n"),
      Tag.replace("head", ""),
      Tag.li(),
      Tag.link(),
      Tag.image(),
      Tag.code(),
      Tag.blockquote(),
      Tag.table(),
      Tag.tr(),
      Tag.ol(),
      Tag.list("ul"),
      Tag.span(),
      Tag.div(),
    ];

    for (const tag of allTags) {
      tagsMap.set(tag.tagName, tag);
    }
  }

  return tagsMap.get(name);
}

class Element {
  static toMarkdown(element, parent, prev, next, metadata) {
    return new Element(element, parent, prev, next, metadata).toMarkdown();
  }

  static parseChildren(parent) {
    return Element.parse(parent.children, parent);
  }

  static parse(elements, parent = null) {
    if (elements) {
      let result = [];
      let metadata = {};

      for (let i = 0; i < elements.length; i++) {
        const prev = i === 0 ? null : elements[i - 1];
        const next = i === elements.length ? null : elements[i + 1];

        result.push(
          Element.toMarkdown(elements[i], parent, prev, next, metadata)
        );
      }

      return result.join("");
    }

    return "";
  }

  constructor(element, parent, previous, next, metadata) {
    this.name = element.name;
    this.data = element.data;
    this.metadata = metadata;
    this.children = element.children;
    this.attributes = element.attributes;

    if (parent) {
      this.parent = parent;
      this.parentNames = parent.parentNames.slice();
      this.parentNames.push(parent.name);
    }

    this.parentNames = this.parentNames || [];
    this.previous = previous;
    this.next = next;

    if (this.name === "p" && MSO_LIST_CLASSES.includes(this.attributes.class)) {
      this.name = "li";
      this.parentNames.push("ul");
    }
  }

  tag() {
    const tag = new (tagByName(this.name) || Tag)();
    tag.element = this;
    tag.metadata = this.metadata;
    return tag;
  }

  innerMarkdown() {
    return Element.parseChildren(this);
  }

  leftTrimmable() {
    return this.previous && Tag.trimmable().includes(this.previous.name);
  }

  rightTrimmable() {
    return this.next && Tag.trimmable().includes(this.next.name);
  }

  text() {
    let text = this.data || "";

    if (this.leftTrimmable()) {
      text = text.trimStart();
    }

    if (this.rightTrimmable()) {
      text = text.trimEnd();
    }

    text = text.replace(/[\s\t]+/g, " ");
    textDecorateCallbacks.forEach((callback) => {
      const result = callback.call(
        this,
        text,
        this.next,
        this.previous,
        this.metadata
      );

      if (typeof result !== "undefined") {
        text = result;
      }
    });

    return text;
  }

  toMarkdown() {
    return this.name === "#text" ? this.text() : this.tag().toMarkdown();
  }

  filterParentNames(names) {
    return this.parentNames.filter((p) => names.includes(p));
  }
}

function trimUnwanted(html) {
  const body = html.match(/<body[^>]*>([\s\S]*?)<\/body>/);
  html = body ? body[1] : html;
  html = html.replace(/\r|\n|&nbsp;/g, " ");
  html = html.replace(/\u00A0/g, " "); // trim no-break space

  let match;
  while ((match = html.match(/<[^\s>]+[^>]*>\s{2,}<[^\s>]+[^>]*>/))) {
    html = html.replace(match[0], match[0].replace(/>\s{2,}</, "> <"));
  }

  html = html.replace(/<!\[if !?\S*]>[^!]*<!\[endif]>/g, ""); // to support ms word list tags

  return html;
}

function putPlaceholders(html) {
  const codeRegEx = /<code[^>]*>([\s\S]*?)<\/code>/gi;
  const origHtml = html;
  let match = codeRegEx.exec(origHtml);
  let placeholders = [];

  while (match) {
    const placeholder = `DISCOURSE_PLACEHOLDER_${placeholders.length + 1}`;
    const element = document.createElement("div");
    element.innerHTML = match[1];

    const code = element.innerText.replace(/^\n/, "").replace(/\n$/, "");
    placeholders.push([placeholder, code]);
    html = html.replace(match[0], `<code>${placeholder}</code>`);
    match = codeRegEx.exec(origHtml);
  }

  const transformNode = (node) => {
    if (node.nodeName !== "#text" && node.length !== undefined) {
      const ret = [];
      for (let i = 0; i < node.length; ++i) {
        if (node[i].nodeName !== "#comment") {
          ret.push(transformNode(node[i]));
        }
      }
      return ret;
    }

    const ret = {
      name: node.nodeName.toLowerCase(),
      data: node.data,
      children: [],
      attributes: {},
    };

    if (node.nodeName === "#text") {
      return ret;
    }

    for (let i = 0; i < node.childNodes.length; ++i) {
      if (node.childNodes[i].nodeName !== "#comment") {
        ret.children.push(transformNode(node.childNodes[i]));
      }
    }

    for (let i = 0; i < node.attributes.length; ++i) {
      ret.attributes[node.attributes[i].name] = node.attributes[i].value;
    }

    return ret;
  };

  const template = document.createElement("template");
  template.innerHTML = trimUnwanted(html);
  const elements = transformNode(template.content.childNodes);

  return { elements, placeholders };
}

function replacePlaceholders(markdown, placeholders) {
  placeholders.forEach((p) => {
    markdown = markdown.replace(p[0], p[1]);
  });
  return markdown;
}

export default function toMarkdown(html) {
  try {
    const { elements, placeholders } = putPlaceholders(html);
    let markdown = Element.parse(elements).trim();
    markdown = markdown
      .replace(/^<b>/, "")
      .replace(/<\/b>$/, "")
      .trim(); // fix for google doc copy paste
    markdown = markdown
      .replace(/\n +/g, "\n")
      .replace(/ +\n/g, "\n")
      .replace(/ {2,}/g, " ")
      .replace(/\n{3,}/g, "\n\n")
      .replace(/\t/g, "  ");
    return replacePlaceholders(markdown, placeholders);
  } catch {
    return "";
  }
}
