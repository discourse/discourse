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
    return this.currentUser.sidebarTagNames.map((tagName) => {
      return new TagSectionLink({
        tagName,
        topicTrackingState: this.topicTrackingState,
      });
    });
  }

  get noTagsText() {
    return I18n.t("sidebar.sections.tags.no_tags", {
      url: `/u/${this.currentUser.username}/preferences/sidebar`,
    });
  }

  @action
  editTracked() {
    this.router.transitionTo("preferences.sidebar", this.currentUser);
  }
}
