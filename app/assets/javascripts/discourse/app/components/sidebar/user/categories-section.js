import I18n from "I18n";

import { cached } from "@glimmer/tracking";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";

import Component from "@glimmer/component";
import CategorySectionLink from "discourse/lib/sidebar/user/categories-section/category-section-link";
import { canDisplayCategory } from "discourse/lib/sidebar/helpers";

export default class SidebarUserCategoriesSection extends Component {
  @service router;
  @service topicTrackingState;
  @service currentUser;
  @service siteSettings;

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

  @cached
  get sectionLinks() {
    const links = [];

    const categories = this.currentUser.sidebarCategories.filter((category) => {
      return canDisplayCategory(category, this.siteSettings);
    });

    for (const category of categories) {
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
