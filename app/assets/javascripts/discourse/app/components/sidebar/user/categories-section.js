import I18n from "I18n";

import { inject as service } from "@ember/service";
import { action } from "@ember/object";

import { canDisplayCategory } from "discourse/lib/sidebar/helpers";
import SidebarCommonCategoriesSection from "discourse/components/sidebar/common/categories-section";

export default class SidebarUserCategoriesSection extends SidebarCommonCategoriesSection {
  @service router;
  @service currentUser;

  constructor() {
    super(...arguments);

    this.callbackId = this.topicTrackingState.onStateChange(() => {
      this.sectionLinks.forEach((sectionLink) => {
        sectionLink.refreshCounts();
      });
    });
  }

  willDestroy() {
    super.willDestroy(...arguments);

    this.topicTrackingState.offStateChange(this.callbackId);
  }

  get categories() {
    return this.currentUser.sidebarCategories.filter((category) => {
      return canDisplayCategory(category, this.siteSettings);
    });
  }

  get noCategoriesText() {
    const url = `/u/${this.currentUser.username}/preferences/sidebar`;

    return `${I18n.t(
      "sidebar.sections.categories.none"
    )} <a href="${url}">${I18n.t(
      "sidebar.sections.categories.click_to_get_started"
    )}</a>`;
  }

  /**
   * If a site has no default sidebar categories configured, show categories section if the user has categories configured.
   * Otherwise, hide the categories section from the sidebar for the user.
   *
   * If a site has default sidebar categories configured, always show categories section for the user.
   */
  get shouldDisplay() {
    if (this.hasDefaultSidebarCategories) {
      return true;
    } else {
      return this.categories.length > 0;
    }
  }

  get hasDefaultSidebarCategories() {
    return this.siteSettings.default_sidebar_categories.length > 0;
  }

  @action
  editTracked() {
    this.router.transitionTo("preferences.sidebar", this.currentUser);
  }
}
