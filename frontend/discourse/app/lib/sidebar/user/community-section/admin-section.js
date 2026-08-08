import { action } from "@ember/object";
import { service } from "@ember/service";
import SidebarSectionForm from "discourse/components/modal/sidebar-section-form";
import { ajax } from "discourse/lib/ajax";
import CommonCommunitySection from "discourse/lib/sidebar/common/community-section/section";
import { i18n } from "discourse-i18n";

export default class extends CommonCommunitySection {
  @service modal;
  @service navigationMenu;

  @action
  async moreSectionButtonAction() {
    const json = await ajax(`/sidebar_sections/${this.section.id}.json`);

    return this.modal.show(SidebarSectionForm, {
      model: {
        hideSectionHeader: this.hideSectionHeader,
        section: json.sidebar_section,
      },
    });
  }

  get moreSectionButtonText() {
    return i18n(
      `sidebar.sections.community.edit_section.${this.navigationMenu.displayMode}`
    );
  }

  get moreSectionButtonIcon() {
    return "pencil";
  }
}
