import { action } from "@ember/object";
import { service } from "@ember/service";
import SidebarSectionForm from "discourse/components/modal/sidebar-section-form";
import CommonCommunitySection from "discourse/lib/sidebar/common/community-section/section";
import { i18n } from "discourse-i18n";

export default class extends CommonCommunitySection {
  @service modal;
  @service navigationMenu;

  @action
  moreSectionButtonAction() {
    return this.modal.show(SidebarSectionForm, { model: this });
  }

  get moreSectionButtonText() {
    return i18n(
      `sidebar.sections.community.edit_section.${
        this.navigationMenu.isDesktopDropdownMode
          ? "header_dropdown"
          : "sidebar"
      }`
    );
  }

  get moreSectionButtonIcon() {
    return "pencil";
  }
}
