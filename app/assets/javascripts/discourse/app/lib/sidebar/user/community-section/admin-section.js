import I18n from "I18n";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";

import CommonCommunitySection from "discourse/lib/sidebar/common/community-section/section";
import SidebarSectionForm from "discourse/components/modal/sidebar-section-form";

export default class extends CommonCommunitySection {
  @service modal;
  @service navigationMenu;

  @action
  moreSectionButtonAction() {
    return this.modal.show(SidebarSectionForm, { model: this });
  }

  get moreSectionButtonText() {
    return I18n.t(
      `sidebar.sections.community.edit_section.${
        this.navigationMenu.isDesktopDropdownMode
          ? "header_dropdown"
          : "sidebar"
      }`
    );
  }

  get moreSectionButtonIcon() {
    return "pencil-alt";
  }
}
