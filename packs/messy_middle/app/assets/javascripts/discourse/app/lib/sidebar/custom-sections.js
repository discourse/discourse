import BaseCustomSidebarSection from "discourse/lib/sidebar/base-custom-sidebar-section";
import BaseCustomSidebarSectionLink from "discourse/lib/sidebar/base-custom-sidebar-section-link";

export const customSections = [];

export function addSidebarSection(func) {
  customSections.push(
    func.call(this, BaseCustomSidebarSection, BaseCustomSidebarSectionLink)
  );
}

export function resetSidebarSection() {
  customSections.length = 0;
}
