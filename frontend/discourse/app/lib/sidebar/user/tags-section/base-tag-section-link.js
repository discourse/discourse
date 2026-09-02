import { originalTagName, tagIdentifiers } from "discourse/lib/tag-identity";

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

  // `tagName` is a display string and holds a localization when one applies.
  get originalName() {
    return originalTagName(this.tag);
  }

  get text() {
    return this.tagName;
  }

  // The link text already names the tag. A title here would only repeat the
  // description as a mouse-only tooltip that screen readers announce.
  get title() {
    return null;
  }

  get prefixType() {
    return "icon";
  }

  get prefixValue() {
    return this.#customPrefixIcon?.prefixValue || "tag";
  }

  get prefixColor() {
    return this.#customPrefixIcon?.prefixColor;
  }

  get #customPrefixIcon() {
    const identifier = tagIdentifiers(this.tag).find(
      (candidate) => customTagSectionLinkPrefixIcons[candidate]
    );

    return customTagSectionLinkPrefixIcons[identifier];
  }
}
