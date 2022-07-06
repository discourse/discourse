import BaseSectionHeader from "discourse/lib/sidebar/base-section-header";
import BaseSectionLink from "discourse/lib/sidebar/base-section-link";

export const customSections = [];

export function addSidebarSection(arg) {
  customSections.push(arg.call(this, BaseSectionHeader, BaseSectionLink));
}
