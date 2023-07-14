import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { cached } from "@glimmer/tracking";

import { debounce } from "discourse-common/utils/decorators";
import Category from "discourse/models/category";
import SidebarCommonCategoriesSection from "discourse/components/sidebar/common/categories-section";
import { hasDefaultSidebarCategories } from "discourse/lib/sidebar/helpers";
import SidebarEditNavigationMenuCategoriesModal from "discourse/components/sidebar/edit-navigation-menu/categories-modal";

export const REFRESH_COUNTS_APP_EVENT_NAME =
  "sidebar:refresh-categories-section-counts";

export default class SidebarUserCategoriesSection extends SidebarCommonCategoriesSection {
  @service appEvents;
  @service currentUser;
  @service modal;
  @service router;

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
  showModal() {
    this.modal.show(SidebarEditNavigationMenuCategoriesModal);
  }
}
