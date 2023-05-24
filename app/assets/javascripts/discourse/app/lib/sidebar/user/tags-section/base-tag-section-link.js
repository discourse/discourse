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
  constructor({ tagName, currentUser }) {
    this.tagName = tagName;
    this.currentUser = currentUser;
  }

  get name() {
    return this.tagName;
  }

  get text() {
    return this.tagName;
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
