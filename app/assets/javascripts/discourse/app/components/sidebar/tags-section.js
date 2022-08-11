import I18n from "I18n";

import { cached } from "@glimmer/tracking";
import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";

import TagSectionLink from "discourse/lib/sidebar/tags-section/tag-section-link";
import PMTagSectionLink from "discourse/lib/sidebar/tags-section/pm-tag-section-link";

export default class SidebarTagsSection extends Component {
  @service router;
  @service topicTrackingState;
  @service pmTopicTrackingState;
  @service currentUser;

  constructor() {
    super(...arguments);

    this.callbackId = this.topicTrackingState.onStateChange(() => {
      this.sectionLinks.forEach((sectionLink) => {
        if (sectionLink.refreshCounts) {
          sectionLink.refreshCounts();
        }
      });
    });
  }

  willDestroy() {
    this.topicTrackingState.offStateChange(this.callbackId);
  }

  @cached
  get sectionLinks() {
    const links = [];

    for (const tag of this.currentUser.sidebarTags) {
      if (tag.pm_only) {
        links.push(
          new PMTagSectionLink({
            tag,
            currentUser: this.currentUser,
          })
        );
      } else {
        links.push(
          new TagSectionLink({
            tag,
            topicTrackingState: this.topicTrackingState,
          })
        );
      }
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
