import I18n from "I18n";

import { cached } from "@glimmer/tracking";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";

import GlimmerComponent from "discourse/components/glimmer";
import CategorySectionLink from "discourse/lib/sidebar/categories-section/category-section-link";

export default class SidebarCategoriesSection extends GlimmerComponent {
  @service router;

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

    for (const category of this.currentUser.sidebarCategories) {
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
