import I18n from "I18n";

import { cached } from "@glimmer/tracking";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";
import { isEmpty } from "@ember/utils";

import Component from "@glimmer/component";
import CategorySectionLink from "discourse/lib/sidebar/categories-section/category-section-link";

export default class SidebarCategoriesSection extends Component {
  @service router;
  @service topicTrackingState;
  @service currentUser;
  @service siteSettings;
  @service site;

  constructor() {
    super(...arguments);

    this.callbackId = this.topicTrackingState.onStateChange(() => {
      this.sectionLinks.forEach((sectionLink) => {
        sectionLink.refreshCounts();
      });
    });
  }

  willDestroy() {
    this.topicTrackingState.offStateChange(this.callbackId);
  }

  get sidebarCategories() {
    if (!isEmpty(this.currentUser.sidebarCategories)) {
      return this.currentUser.sidebarCategories;
    }
    if (
      this.currentUser &&
      !isEmpty(this.siteSettings.default_sidebar_categories)
    ) {
      const categoryIds = this.siteSettings.default_sidebar_categories
        .split("|")
        .map((id) => parseInt(id, 10));

      return this.site.categories.filter((category) =>
        categoryIds.includes(category.id)
      );
    }
    return [];
  }

  @cached
  get sectionLinks() {
    const links = [];

    for (const category of this.sidebarCategories) {
      links.push(
        new CategorySectionLink({
          category,
          topicTrackingState: this.topicTrackingState,
        })
      );
    }

    return links;
  }

  get noCategoriesText() {
    const url = `/u/${this.currentUser.username}/preferences/sidebar`;

    return `${I18n.t(
      "sidebar.sections.categories.none"
    )} <a href="${url}">${I18n.t(
      "sidebar.sections.categories.click_to_get_started"
    )}</a>`;
  }

  @action
  editTracked() {
    this.router.transitionTo("preferences.sidebar", this.currentUser);
  }
}
