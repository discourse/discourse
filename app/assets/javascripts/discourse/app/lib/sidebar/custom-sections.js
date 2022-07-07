import BaseSectionHeader from "discourse/lib/sidebar/base-section-header";
import BaseSectionLink from "discourse/lib/sidebar/base-section-link";

export const customSections = [];

export function addSidebarSection(func) {
  customSections.push(func.call(this, BaseSectionHeader, BaseSectionLink));
}
