import parseHTML from "discourse/helpers/parse-html";

const trimLeft = text => text.replace(/^\s+/, "");
const trimRight = text => text.replace(/\s+$/, "");
const countPipes = text => (text.replace(/\\\|/, "").match(/\|/g) || []).length;
const msoListClasses = [
  "MsoListParagraphCxSpFirst",
  "MsoListParagraphCxSpMiddle",
  "MsoListParagraphCxSpLast"
];

export class Tag {
  constructor(name, prefix = "", suffix = "", inline = false) {
    this.name = name;
    this.prefix = prefix;
    this.suffix = suffix;
    this.inline = inline;
  }

  decorate(text) {
    if (this.prefix || this.suffix) {
      text = [this.prefix, text, this.suffix].join("");
    }

    if (this.inline) {
      text = " " + text + " ";
    }

    return text;
  }

  toMarkdown() {
    const text = this.element.innerMarkdown();

    if (text && text.trim()) {
      return this.decorate(text);
    }

    return text;
  }

  static blocks() {
    return [
      "address",
      "article",
      "aside",
      "dd",
      "div",
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
      "section"
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
      ["strike", "~~"]
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
      "li",
      "td",
      "th",
      "br",
      "hr",
      "blockquote",
      "table",
      "ol",
      "tr",
      "ul"
    ];
  }

  static block(name, prefix, suffix) {
    return class extends Tag {
      constructor() {
        super(name, prefix, suffix);
        this.gap = "\n\n";
      }

      decorate(text) {
        const parent = this.element.parent;

        if (this.name === "p" && parent && parent.name === "li") {
          // fix for google docs
          this.gap = "";
        }

        return `${this.gap}${this.prefix}${text}${this.suffix}${this.gap}`;
      }
    };
  }

  static heading(name, i) {
    const prefix = `${[...Array(i)].map(() => "#").join("")} `;
    return Tag.block(name, prefix, "");
  }

  static emphasis(name, decorator) {
    return class extends Tag {
      constructor() {
        super(name, decorator, decorator, true);
      }

      decorate(text) {
        if (text.includes("\n")) {
          this.prefix = `<${this.name}>`;
          this.suffix = `</${this.name}>`;
        }

        let space = text.match(/^\s/) || [""];
        this.prefix = space[0] + this.prefix;
        space = text.match(/\s$/) || [""];
        this.suffix = this.suffix + space[0];

        return super.decorate(text.trim());
      }
    };
  }

  static keep(name) {
    return class extends Tag {
      constructor() {
        super(name, `<${name}>`, `</${name}>`);
      }
    };
  }

  static replace(name, text) {
    return class extends Tag {
      constructor() {
        super(name, "", "");
        this.text = text;
      }

      toMarkdown() {
        return this.text;
      }
    };
  }

  static span() {
    return class extends Tag {
      constructor() {
        super("span");
      }

      decorate(text) {
        const attr = this.element.attributes;

        if (attr.class === "badge badge-notification clicks") {
          return "";
        }

        return super.decorate(text);
      }
    };
  }

  static link() {
    return class extends Tag {
      constructor() {
        super("a", "", "", true);
      }

      decorate(text) {
        const attr = this.element.attributes;

        if (/^mention/.test(attr.class) && "@" === text[0]) {
          return text;
        }

        if ("hashtag" === attr.class && "#" === text[0]) {
          return text;
        }

        if (attr.href && text !== attr.href) {
          text = text.replace(/\n{2,}/g, "\n");
          return "[" + text + "](" + attr.href + ")";
        }

        return text;
      }
    };
  }

  static image() {
    return class extends Tag {
      constructor() {
        super("img", "", "", true);
      }

      toMarkdown() {
        const e = this.element;
        const attr = e.attributes;
        const pAttr = (e.parent && e.parent.attributes) || {};
        const src = attr.src || pAttr.src;
        const cssClass = attr.class || pAttr.class;

        if (cssClass && cssClass.includes("emoji")) {
          return attr.title || pAttr.title;
        }

        if (src) {
          let alt = attr.alt || pAttr.alt || "";
          const width = attr.width || pAttr.width;
          const height = attr.height || pAttr.height;

          if (width && height) {
            const pipe = this.element.parentNames.includes("table")
              ? "\\|"
              : "|";
            alt = `${alt}${pipe}${width}x${height}`;
          }

          return "![" + alt + "](" + src + ")";
        }

        return "";
      }
    };
  }

  static slice(name, suffix) {
    return class extends Tag {
      constructor() {
        super(name, "", suffix);
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
    return class extends Tag {
      constructor() {
        super(name, "|");
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
        let indent = this.element
          .filterParentNames(["ol", "ul"])
          .slice(1)
          .map(() => "\t")
          .join("");
        const attrs = this.element.attributes;

        if (msoListClasses.includes(attrs.class)) {
          try {
            const level = parseInt(
              attrs.style.match(/level./)[0].replace("level", "")
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

        return super.decorate(`${indent}* ${trimLeft(text)}`);
      }
    };
  }

  static code() {
    return class extends Tag {
      constructor() {
        super("code", "`", "`");
      }

      decorate(text) {
        if (this.element.parentNames.includes("pre")) {
          this.prefix = "\n\n```\n";
          this.suffix = "\n```\n\n";
        } else {
          this.inline = true;
        }

        text = $("<textarea />")
          .html(text)
          .text();
        return super.decorate(text);
      }
    };
  }

  static blockquote() {
    return class extends Tag {
      constructor() {
        super("blockquote", "\n> ", "\n");
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

      decorate(text) {
        text = super.decorate(text).replace(/\|\n{2,}\|/g, "|\n|");
        const rows = text.trim().split("\n");
        const pipeCount = countPipes(rows[0]);
        this.isValid =
          this.isValid &&
          rows.length > 1 &&
          pipeCount > 2 &&
          rows.reduce((a, c) => a && countPipes(c) <= pipeCount); // Unsupported table format for Markdown conversion

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

        if (parent && parent.name === "ul") {
          this.gap = "";
          this.suffix = "\n";
        }

        if (this.element.filterParentNames(["li"]).length) {
          this.gap = "";
          smallGap = "\n";
        }

        return smallGap + super.decorate(trimRight(text));
      }
    };
  }

  static ol() {
    return class extends Tag.list("ol") {
      decorate(text) {
        text = "\n" + text;
        const bullet = text.match(/\n\t*\*/)[0];

        for (
          let i = parseInt(this.element.attributes.start || 1);
          text.includes(bullet);
          i++
        ) {
          text = text.replace(bullet, bullet.replace("*", `${i}.`));
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
}

function tags() {
  return [
    ...Tag.blocks().map(b => Tag.block(b)),
    ...Tag.headings().map((h, i) => Tag.heading(h, i + 1)),
    ...Tag.slices().map(s => Tag.slice(s, "\n")),
    ...Tag.emphases().map(e => Tag.emphasis(e[0], e[1])),
    Tag.cell("td"),
    Tag.cell("th"),
    Tag.replace("br", "\n"),
    Tag.replace("hr", "\n---\n"),
    Tag.replace("head", ""),
    Tag.keep("ins"),
    Tag.keep("del"),
    Tag.keep("small"),
    Tag.keep("big"),
    Tag.keep("kbd"),
    Tag.li(),
    Tag.link(),
    Tag.image(),
    Tag.code(),
    Tag.blockquote(),
    Tag.table(),
    Tag.tr(),
    Tag.ol(),
    Tag.list("ul"),
    Tag.span()
  ];
}

class Element {
  constructor(element, parent, previous, next) {
    this.name = element.name;
    this.type = element.type;
    this.data = element.data;
    this.children = element.children;
    this.attributes = element.attributes || {};

    if (parent) {
      this.parent = parent;
      this.parentNames = parent.parentNames.slice();
      this.parentNames.push(parent.name);
    }

    this.parentNames = this.parentNames || [];
    this.previous = previous;
    this.next = next;

    if (this.name === "p") {
      if (msoListClasses.includes(this.attributes.class)) {
        this.name = "li";
        this.parentNames.push("ul");
      }
    }
  }

  tag() {
    const tag = new (tags().filter(t => new t().name === this.name)[0] ||
      Tag)();
    tag.element = this;
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
      text = trimLeft(text);
    }

    if (this.rightTrimmable()) {
      text = trimRight(text);
    }

    text = text.replace(/[ \t]+/g, " ");

    return text;
  }

  toMarkdown() {
    switch (this.type) {
      case "text":
        return this.text();
        break;
      case "tag":
        return this.tag().toMarkdown();
        break;
    }
  }

  filterParentNames(names) {
    return this.parentNames.filter(p => names.includes(p));
  }

  static toMarkdown(element, parent, prev, next) {
    return new Element(element, parent, prev, next).toMarkdown();
  }

  static parseChildren(parent) {
    return Element.parse(parent.children, parent);
  }

  static parse(elements, parent = null) {
    if (elements) {
      let result = [];

      for (let i = 0; i < elements.length; i++) {
        const prev = i === 0 ? null : elements[i - 1];
        const next = i === elements.length ? null : elements[i + 1];

        result.push(Element.toMarkdown(elements[i], parent, prev, next));
      }

      return result.join("");
    }

    return "";
  }
}

function trimUnwanted(html) {
  const body = html.match(/<body[^>]*>([\s\S]*?)<\/body>/);
  html = body ? body[1] : html;
  html = html.replace(/\r|\n|&nbsp;/g, " ");

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
    let code = match[1];
    code = $("<div />")
      .html(code)
      .text()
      .replace(/^\n/, "")
      .replace(/\n$/, "");
    placeholders.push([placeholder, code]);
    html = html.replace(match[0], `<code>${placeholder}</code>`);
    match = codeRegEx.exec(origHtml);
  }

  const elements = parseHTML(trimUnwanted(html));
  return { elements, placeholders };
}

function replacePlaceholders(markdown, placeholders) {
  placeholders.forEach(p => {
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
  } catch (err) {
    return "";
  }
}
