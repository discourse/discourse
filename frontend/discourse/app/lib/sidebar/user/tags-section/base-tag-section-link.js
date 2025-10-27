import escape from "discourse/lib/escape";

let customTagSectionLinkPrefixIcons = {};

export function registerCustomTagSectionLinkPrefixIcon({
  tagName,
  prefixValue,
  prefixColor,
}) {
  customTagSectionLinkPrefixIcons[tagName] = {
    prefixValue,
    prefixColor,
  };
}

export function resetCustomTagSectionLinkPrefixIcons() {
  for (let key in customTagSectionLinkPrefixIcons) {
    if (customTagSectionLinkPrefixIcons.hasOwnProperty(key)) {
      delete customTagSectionLinkPrefixIcons[key];
    }
  }
}

export default class BaseTagSectionLink {
  constructor({ tag, currentUser }) {
    this.tag = tag;
    this.tagName = tag.name;
    this.currentUser = currentUser;
  }

  get name() {
    return this.tagName;
  }

  get text() {
    return this.tagName;
  }

  get title() {
    return escape(this.tag.description);
  }

  get prefixType() {
    return "icon";
  }

  get prefixValue() {
    return customTagSectionLinkPrefixIcons[this.tagName]?.prefixValue || "tag";
  }

  get prefixColor() {
    return customTagSectionLinkPrefixIcons[this.tagName]?.prefixColor;
  }
}
