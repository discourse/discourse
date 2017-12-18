import parseHTML from 'discourse/helpers/parse-html';

const trimLeft = text => text.replace(/^\s+/,"");
const trimRight = text => text.replace(/\s+$/,"");

class Tag {
  constructor(name, prefix = "", suffix = "") {
    this.name = name;
    this.prefix = prefix;
    this.suffix = suffix;
  }

  decorate(text) {
    if (this.prefix || this.suffix) {
      return [this.prefix, text, this.suffix].join("");
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
    return ["address", "article", "aside", "blockquote", "dd", "div", "dl", "dt", "fieldset",
            "figcaption", "figure", "footer", "form", "header", "hgroup", "hr", "main", "nav",
            "ol", "p", "pre", "section", "table", "ul"];
  }

  static headings() {
    return ["h1", "h2", "h3", "h4", "h5", "h6"];
  }

  static emphases() {
    return  [ ["b", "**"], ["strong", "**"], ["i", "_"], ["em", "_"], ["s", "~~"], ["strike", "~~"] ];
  }

  static slices() {
    return ["dt", "dd", "tr", "thead", "tbody", "tfoot"];
  }

  static trimmable() {
    return [...Tag.blocks(), ...Tag.headings(), ...Tag.slices(), "li", "td", "th", "br", "hr"];
  }

  static block(name, prefix, suffix) {
    return class extends Tag {
      constructor() {
        super(name, prefix, suffix);
      }

      decorate(text) {
        return `\n\n${this.prefix}${text}${this.suffix}\n\n`;
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
        super(name, decorator, decorator);
      }

      decorate(text) {
        text = text.trim();

        if (text.includes("\n")) {
          this.prefix = `<${this.name}>`;
          this.suffix = `</${this.name}>`;
        }

        return super.decorate(text);
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

  static link() {
    return class extends Tag {
      constructor() {
        super("a");
      }

      decorate(text) {
        const attr = this.element.attributes;

        if (attr && attr.href && text !== attr.href) {
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
        super("img");
      }

      toMarkdown() {
        const e = this.element;
        const attr = e.attributes || {};
        const pAttr = (e.parent && e.parent.attributes) || {};
        const src = attr.src || pAttr.src;

        if (src) {
          let alt = attr.alt || pAttr.alt || "";
          const width = attr.width || pAttr.width;
          const height = attr.height || pAttr.height;

          if (width && height) {
            alt = `${alt}|${width}x${height}`;
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
    return Tag.slice(name, " ");
  }

  static li() {
    return class extends Tag.slice("li", "\n") {
      decorate(text) {
        const indent = this.element.filterParentNames("ul").slice(1).map(() => "  ").join("");
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
          this.prefix = '\n\n```\n';
          this.suffix = '\n```\n\n';
        }

        text = $('<textarea />').html(text).text();
        return super.decorate(text);
      }
    };
  }

}

const tags = [
  ...Tag.blocks().map((b) => Tag.block(b)),
  ...Tag.headings().map((h, i) => Tag.heading(h, i + 1)),
  ...Tag.slices().map((s) => Tag.slice(s, "\n")),
  ...Tag.emphases().map((e) => Tag.emphasis(e[0], e[1])),
  Tag.cell("td"), Tag.cell("th"),
  Tag.replace("br", "\n"), Tag.replace("hr", "\n---\n"), Tag.replace("head", ""),
  Tag.keep("ins"), Tag.keep("del"), Tag.keep("small"), Tag.keep("big"),
  Tag.li(), Tag.link(), Tag.image(), Tag.code(),

  // TO-DO  CREATE: code, tbody, blockquote
  //        UPDATE: ol, pre, thead, th, td
];

class Element {
  constructor(element, parent, previous, next) {
    this.name = element.name;
    this.type = element.type;
    this.data = element.data;
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
  }

  tag() {
    const tag = new (tags.filter(t => (new t().name === this.name))[0] || Tag)();
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
    switch(this.type) {
      case "text":
        return this.text();
        break;
      case "tag":
        return this.tag().toMarkdown();
        break;
    }
  }

  filterParentNames(name) {
    return this.parentNames.filter(p => p === name);
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
        const prev = (i === 0) ? null : elements[i-1];
        const next = (i === elements.length) ? null : elements[i+1];

        result.push(Element.toMarkdown(elements[i], parent, prev, next));
      }

      return result.join("");
    }

    return "";
  }
}

function putPlaceholders(html) {
  const codeRegEx = /<code[^>]*>([\s\S]*?)<\/code>/gi;
  const origHtml = html;
  let match = codeRegEx.exec(origHtml);
  let placeholders = [];

  while(match) {
    const placeholder = `DISCOURSE_PLACEHOLDER_${placeholders.length + 1}`;
    let code = match[1];
    code = $('<div />').html(code).text().replace(/^\n/, '').replace(/\n$/, '');
    placeholders.push([placeholder, code]);
    html = html.replace(match[0], `<code>${placeholder}</code>`);
    match = codeRegEx.exec(origHtml);
  }

  const elements = parseHTML(html);
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
    markdown = markdown.replace(/^<b>/, "").replace(/<\/b>$/, "").trim(); // fix for google doc copy paste
    markdown = markdown.replace(/\r/g, "").replace(/\n \n/g, "\n\n").replace(/\n{3,}/g, "\n\n");
    return replacePlaceholders(markdown, placeholders);
  } catch(err) {
    return "";
  }
}
