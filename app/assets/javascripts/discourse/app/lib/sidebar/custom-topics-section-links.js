import BaseSectionLink from "discourse/lib/sidebar/topics-section/base-section-link";

export let customSectionLinks = [];

/**
 * Appends an additional section link under the topics section
 * @callback addSectionLinkCallback
 * @param {BaseSectionLink} baseSectionLink Factory class to inherit from.
 * @returns {BaseSectionLink} A class that extends BaseSectionLink.
 *
 * @param {addTopicsSectionLinkCallback} callback
 */
export function addSectionLink(callback) {
  customSectionLinks.push(callback.call(this, BaseSectionLink));
}

export function resetDefaultSectionLinks() {
  customSectionLinks = [];
}
