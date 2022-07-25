import BaseSectionLink from "discourse/lib/sidebar/community-section/base-section-link";

export let customSectionLinks = [];

/**
 * Appends an additional section link under the topics section
 * @callback addSectionLinkCallback
 * @param {BaseSectionLink} baseSectionLink Factory class to inherit from.
 * @returns {BaseSectionLink} A class that extends BaseSectionLink.
 *
 * @param {(addSectionLinkCallback|Object)} arg - A callback function or an Object.
 * @param {string} arg.name - The name of the link. Needs to be dasherized and lowercase.
 * @param {string} arg.route - The Ember route of the link.
 * @param {string} arg.title - The title attribute for the link.
 * @param {string} arg.text - The text to display for the link.
 */
export function addSectionLink(arg) {
  if (typeof arg === "function") {
    customSectionLinks.push(arg.call(this, BaseSectionLink));
  } else {
    const klass = class extends BaseSectionLink {
      get name() {
        return arg.name;
      }

      get route() {
        return arg.route;
      }

      get text() {
        return arg.text;
      }

      get title() {
        return arg.title;
      }
    };

    customSectionLinks.push(klass);
  }
}

export function resetDefaultSectionLinks() {
  customSectionLinks = [];
}
