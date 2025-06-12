import BaseCustomSidebarSectionLink from "discourse/lib/sidebar/base-custom-sidebar-section-link";

export let customSectionMoreLinks = {};

/**
 * Appends an additional section link to the "More..." dropdown of a custom sidebar section.
 *
 * @callback addMoreLinkCallback
 * @param {BaseCustomSidebarSectionLink} baseSectionLink Factory class to inherit from.
 * @returns {BaseCustomSidebarSectionLink} A class that extends BaseCustomSidebarSectionLink.
 *
 * @param {string} sectionName - The name of the custom section to add the link to.
 * @param {(addMoreLinkCallback|Object)} args - A callback function or an Object.
 * @param {string} args.name - The name of the link. Needs to be dasherized and lowercase.
 * @param {string} args.text - The text to display for the link.
 * @param {string} [args.route] - The Ember route name to generate the href attribute for the link.
 * @param {string} [args.href] - The href attribute for the link.
 * @param {string} [args.title] - The title attribute for the link.
 * @param {string} [args.icon] - The FontAwesome icon to display for the link.
 */

export function addCustomSectionMoreLink(sectionName, args) {
  if (!customSectionMoreLinks[sectionName]) {
    customSectionMoreLinks[sectionName] = [];
  }

  const links = customSectionMoreLinks[sectionName];

  if (typeof args === "function") {
    links.push(args.call(this, BaseCustomSidebarSectionLink));
  } else {
    const klass = class extends BaseCustomSidebarSectionLink {
      get name() {
        return args.name;
      }

      get text() {
        return args.text;
      }

      get title() {
        return args.title || args.text;
      }

      get href() {
        return args.href;
      }

      get route() {
        return args.route;
      }

      get prefixType() {
        return args.icon ? "icon" : super.prefixType;
      }

      get prefixValue() {
        return args.icon || super.prefixValue;
      }
    };

    links.push(klass);
  }
}

/**
 * Get the more links for a specific custom section.
 *
 * @param {string} sectionName - The name of the custom section.
 * @returns {Array} Array of link classes for the section.
 */
export function getCustomSectionMoreLinks(sectionName) {
  return customSectionMoreLinks[sectionName] || [];
}

/**
 * Reset all custom section more links.
 */
export function resetCustomSectionMoreLinks() {
  customSectionMoreLinks = {};
}
