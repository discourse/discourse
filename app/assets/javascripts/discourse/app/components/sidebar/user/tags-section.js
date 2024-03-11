import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import SidebarEditNavigationMenuTagsModal from "discourse/components/sidebar/edit-navigation-menu/tags-modal";
import { hasDefaultSidebarTags } from "discourse/lib/sidebar/helpers";
import PMTagSectionLink from "discourse/lib/sidebar/user/tags-section/pm-tag-section-link";
import TagSectionLink from "discourse/lib/sidebar/user/tags-section/tag-section-link";

export default class SidebarUserTagsSection extends Component {
  @service currentUser;
  @service modal;
  @service pmTopicTrackingState;
  @service router;
  @service site;
  @service siteSettings;
  @service topicTrackingState;

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
    super.willDestroy(...arguments);
    this.topicTrackingState.offStateChange(this.callbackId);
  }

  @cached
  get sectionLinks() {
    const links = [];

    let tags;

    if (this.currentUser.sidebarTags.length > 0) {
      tags = this.currentUser.sidebarTags;
    } else {
      tags = this.site.navigation_menu_site_top_tags || [];
    }

    for (const tag of tags) {
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
            currentUser: this.currentUser,
          })
        );
      }
    }

    return links;
  }

  get shouldDisplayDefaultConfig() {
    return this.currentUser.admin && !this.hasDefaultSidebarTags;
  }

  get hasDefaultSidebarTags() {
    return hasDefaultSidebarTags(this.siteSettings);
  }

  @action
  showModal() {
    this.modal.show(SidebarEditNavigationMenuTagsModal);
  }
}
