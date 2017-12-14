import parseHTML from 'discourse/helpers/parse-html';

function trimLeft(text) {
    return text.replace(/^\s+/,"");
}

class Tag {
  constructor(name, prefix, suffix) {
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

  innerMarkdown() {
    let text = this.element.innerMarkdown();

    if (this.element.name !== 'li') {
      text = text.replace(/^ +/g, "");
    }

    return text;
  }

  toMarkdown() {
    const text = this.innerMarkdown();

    if (text && text.trim()) {
      return this.decorate(text);
    }

    return text;
  }

  static heading(name, prefix) {
    return class extends Tag {
      constructor() {
        super(name, `\n\n${prefix} `, "\n\n");
      }
    };
  }

  static emphasis(name, decorator) {
    return class extends Tag {
      constructor() {
        super(name, decorator, decorator);
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

  static separator(name, text) {
    return Tag.replace(name, text);
  }

  static region(name) {
    return class extends Tag {
      constructor() {
        super(name, "\n\n", "\n\n");
      }
    };
  }

  static link() {
    return class extends Tag {
      constructor() {
        super("a", "", "");
      }

      decorate(text) {
        const attr = this.element.attributes;

        if (!text) {
          return "";
        } else if (attr && attr.href && text !== attr.href) {
          return "[" + text + "](" + attr.href + ")";
        }

        return text;
      }
    };
  }

  static listItem() {
    return class extends Tag {
      constructor() {
        super("li", "", "\n");
      }

      decorate(text) {
        const indent = this.element.filterParentNames("li").map(() => "  ").join("");
        if (!this.element.next) {
          this.suffix = "";
        }
        return `${indent}* ${trimLeft(text)}${this.suffix}`;
      }
    };
  }

}

const tags = [
  Tag.heading("h1", "#"),
  Tag.heading("h2", "##"),
  Tag.heading("h3", "###"),
  Tag.heading("h4", "####"),
  Tag.heading("h5", "#####"),
  Tag.heading("h6", "######"),

  Tag.emphasis("b", "**"), Tag.emphasis("strong", "**"),
  Tag.emphasis("i", "_"), Tag.emphasis("em", "_"),
  Tag.emphasis("s", "~~"), Tag.emphasis("strike", "~~"),

  Tag.region("p"), Tag.region("div"),, Tag.region("table"),
  Tag.region("ul"), Tag.region("ol"), Tag.region("dl"),

  Tag.listItem(),

  Tag.separator("br", "\n"),
  Tag.separator("hr", "\n---\n"),

  Tag.link(),

  Tag.replace("head", ""),

  // TODO: img, pre, code, dt, dd, thead, tbody, tr, th, td, ins, del, blockquote
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
      this.parentNames = (parent.parentNames || []).slice();
      this.parentNames.push(parent.name);
    }
    this.previous = previous;
    this.next = next;
  }

  tag() {
    let tag = tags.filter(t => (new t().name === this.name))[0] || Tag;
    tag = new tag();
    tag.element = this;
    return tag;
  }

  innerMarkdown() {
    return Element.parseChildren(this);
  }

  toMarkdown() {
    switch(this.type) {
      case "text":
        return this.data;
        break;
      case "tag":
        return this.tag().toMarkdown();
        break;
    }
  }

  isInside(name) {
    return this.name === name || this.filterParentNames(name)[0];
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

export default function toMarkdown(html) {
  try {
    let markdown = Element.parse(parseHTML(html)).trim();
    return markdown.replace(/\r/g, "").replace(/\n{4,}/g, "\n\n\n");
  } catch(err) {
    return "";
  }
}
