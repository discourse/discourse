import I18n from "I18n";

import { cached } from "@glimmer/tracking";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";

import GlimmerComponent from "discourse/components/glimmer";
import TagSectionLink from "discourse/lib/sidebar/tags-section/tag-section-link";

export default class SidebarTagsSection extends GlimmerComponent {
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

    for (const tagName of this.currentUser.sidebarTagNames) {
      links.push(
        new TagSectionLink({
          tagName,
          topicTrackingState: this.topicTrackingState,
        })
      );
    }

    return links;
  }

  get noTagsText() {
    const url = `/u/${this.currentUser.username}/preferences/sidebar`;

    return `${I18n.t("sidebar.sections.tags.none")} <a href="${url}">${I18n.t(
      "sidebar.sections.tags.click_to_get_started"
    )}</a>`;
  }

  @action
  editTracked() {
    this.router.transitionTo("preferences.sidebar", this.currentUser);
  }
}
