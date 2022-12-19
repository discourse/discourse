import { inject as service } from "@ember/service";
import { action } from "@ember/object";
import { cached } from "@glimmer/tracking";

import Category from "discourse/models/category";
import SidebarCommonCategoriesSection from "discourse/components/sidebar/common/categories-section";
import discourseDebounce from "discourse-common/lib/debounce";

export const REFRESH_COUNTS_APP_EVENT_NAME =
  "sidebar:refresh-categories-section-counts";

export default class SidebarUserCategoriesSection extends SidebarCommonCategoriesSection {
  @service router;
  @service currentUser;
  @service appEvents;

  constructor() {
    super(...arguments);

    this.callbackId = this.topicTrackingState.onStateChange(() => {
      this.#refreshCounts();
    });

    this.appEvents.on(REFRESH_COUNTS_APP_EVENT_NAME, this, this.#refreshCounts);
  }

  willDestroy() {
    super.willDestroy(...arguments);

    this.topicTrackingState.offStateChange(this.callbackId);

    this.appEvents.off(
      REFRESH_COUNTS_APP_EVENT_NAME,
      this,
      this.#refreshCounts
    );
  }

  #refreshCounts() {
    // TopicTrackingState changes or plugins can trigger this function so we debounce to ensure we're not refreshing
    // unnecessarily.
    discourseDebounce(
      this,
      () => {
        this.sectionLinks.forEach((sectionLink) => {
          sectionLink.refreshCounts();
        });
      },
      300
    );
  }

  @cached
  get categories() {
    return Category.findByIds(this.currentUser.sidebarCategoryIds);
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
