import { cached } from "@glimmer/tracking";
import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";

import TagSectionLink from "discourse/lib/sidebar/user/tags-section/tag-section-link";
import PMTagSectionLink from "discourse/lib/sidebar/user/tags-section/pm-tag-section-link";

export default class SidebarUserTagsSection extends Component {
  @service router;
  @service topicTrackingState;
  @service pmTopicTrackingState;
  @service currentUser;
  @service siteSettings;

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
            tagName: tag.name,
            currentUser: this.currentUser,
          })
        );
      } else {
        links.push(
          new TagSectionLink({
            tagName: tag.name,
            topicTrackingState: this.topicTrackingState,
            currentUser: this.currentUser,
          })
        );
      }
    }

    return links;
  }

  /**
   * If a site has no default sidebar tags configured, show tags section if the user has personal sidebar tags configured.
   * Otherwise, hide the tags section from the sidebar for the user.
   *
   * If a site has default sidebar tags configured, always display the tags section.
   */
  get shouldDisplay() {
    if (this.hasDefaultSidebarTags) {
      return true;
    } else {
      return this.currentUser.sidebarTags.length > 0;
    }
  }

  get shouldDisplayDefaultConfig() {
    return this.currentUser.admin && !this.hasDefaultSidebarTags;
  }

  get hasDefaultSidebarTags() {
    return this.siteSettings.default_sidebar_tags.length > 0;
  }

  @action
  editTracked() {
    this.router.transitionTo("preferences.sidebar", this.currentUser);
  }
}
