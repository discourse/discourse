import BaseCommunitySectionLink from "discourse/lib/sidebar/base-community-section-link";

export let customSectionLinks = [];
export let secondaryCustomSectionLinks = [];

/**
 * Appends an additional section link to the Community section under the "More..." links drawer.
 *
 * @callback addSectionLinkCallback
 * @param {BaseCommunitySectionLink} baseCommunitySectionLink Factory class to inherit from.
 * @returns {BaseCommunitySectionLink} A class that extends BaseCommunitySectionLink.
 *
 * @param {(addSectionLinkCallback|Object)} args - A callback function or an Object.
 * @param {string} args.name - The name of the link. Needs to be dasherized and lowercase.
 * @param {string} args.text - The text to display for the link.
 * @param {string} [args.route] - The Ember route name to generate the href attribute for the link.
 * @param {string} [args.href] - The href attribute for the link.
 * @param {string} [args.title] - The title attribute for the link.
 * @param {string} [args.icon] - The FontAwesome icon to display for the link.
 * @param {Boolean} [secondary] - Determines whether the section link should be added to the main or secondary section in the "More..." links drawer.
 */
export function addSectionLink(args, secondary) {
  const links = secondary ? secondaryCustomSectionLinks : customSectionLinks;

  if (typeof args === "function") {
    links.push(args.call(this, BaseCommunitySectionLink));
  } else {
    const klass = class extends BaseCommunitySectionLink {
      get name() {
        return args.name;
      }

      get text() {
        return args.text;
      }

      get title() {
        return args.title;
      }

      get href() {
        return args.href;
      }

      get route() {
        return args.route;
      }

      get prefixValue() {
        return args.icon || super.prefixValue;
      }
    };

    links.push(klass);
  }
}

export function resetDefaultSectionLinks() {
  customSectionLinks.length = 0;
  secondaryCustomSectionLinks.length = 0;
}
