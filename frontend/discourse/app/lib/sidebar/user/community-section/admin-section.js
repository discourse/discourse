import { action } from "@ember/object";
import { service } from "discourse/lib/service";
import { ajax } from "discourse/lib/ajax";
import CommonCommunitySection from "discourse/lib/sidebar/common/community-section/section";
import { i18n } from "discourse-i18n";
import ModalService from "discourse/services/modal";
import NavigationMenuService from "discourse/services/navigation-menu";

export default class extends CommonCommunitySection {
  @service(() => ModalService) modal;
  @service(() => NavigationMenuService) navigationMenu;

  get moreSectionButtonText() {
    return i18n(
      `sidebar.sections.community.edit_section.${this.navigationMenu.displayMode}`
    );
  }

  get moreSectionButtonIcon() {
    return "pencil";
  }

  @action
  async moreSectionButtonAction() {
    const json = await ajax(`/sidebar_sections/${this.section.id}.json`);

    return this.modal.show(
      () => import("discourse/components/modal/sidebar-section-form"),
      {
        model: {
          hideSectionHeader: this.hideSectionHeader,
          section: json.sidebar_section,
        },
      }
    );
  }
}
