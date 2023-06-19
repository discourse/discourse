import { inject as service } from "@ember/service";
import { action } from "@ember/object";
import { cached } from "@glimmer/tracking";

import { debounce } from "discourse-common/utils/decorators";
import Category from "discourse/models/category";
import SidebarCommonCategoriesSection from "discourse/components/sidebar/common/categories-section";
import showModal from "discourse/lib/show-modal";
import { hasDefaultSidebarCategories } from "discourse/lib/sidebar/helpers";

export const REFRESH_COUNTS_APP_EVENT_NAME =
  "sidebar:refresh-categories-section-counts";

export default class SidebarUserCategoriesSection extends SidebarCommonCategoriesSection {
  @service router;
  @service currentUser;
  @service appEvents;

  constructor() {
    super(...arguments);

    this.callbackId = this.topicTrackingState.onStateChange(() => {
      this._refreshCounts();
    });

    this.appEvents.on(REFRESH_COUNTS_APP_EVENT_NAME, this, this._refreshCounts);
  }

  willDestroy() {
    super.willDestroy(...arguments);

    this.topicTrackingState.offStateChange(this.callbackId);

    this.appEvents.off(
      REFRESH_COUNTS_APP_EVENT_NAME,
      this,
      this._refreshCounts
    );
  }

  // TopicTrackingState changes or plugins can trigger this function so we debounce to ensure we're not refreshing
  // unnecessarily.
  @debounce(300)
  _refreshCounts() {
    this.sectionLinks.forEach((sectionLink) => {
      sectionLink.refreshCounts();
    });
  }

  @cached
  get categories() {
    if (this.currentUser.sidebarCategoryIds?.length > 0) {
      return Category.findByIds(this.currentUser.sidebarCategoryIds);
    } else {
      return this.topSiteCategories;
    }
  }

  get shouldDisplayDefaultConfig() {
    return this.currentUser.admin && !this.hasDefaultSidebarCategories;
  }

  get hasDefaultSidebarCategories() {
    return hasDefaultSidebarCategories(this.siteSettings);
  }

  @action
  editTracked() {
    if (
      this.currentUser.new_edit_sidebar_categories_tags_interface_groups_enabled
    ) {
      showModal("sidebar-categories-form");
    } else {
      this.router.transitionTo("preferences.navigation-menu", this.currentUser);
    }
  }
}
