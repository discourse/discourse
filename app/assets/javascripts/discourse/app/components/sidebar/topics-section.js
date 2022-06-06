import GlimmerComponent from "discourse/components/glimmer";
import Composer from "discourse/models/composer";
import { getOwner } from "discourse-common/lib/get-owner";
import PermissionType from "discourse/models/permission-type";
import { customSectionLinks } from "discourse/lib/sidebar/custom-topics-section-links";
import EverythingSectionLink from "discourse/lib/sidebar/topics-section/everything-section-link";
import TrackedSectionLink from "discourse/lib/sidebar/topics-section/tracked-section-link";
import BookmarkedSectionLink from "discourse/lib/sidebar/topics-section/bookmarked-section-link";
import MyPostsSectionLink from "discourse/lib/sidebar/topics-section/my-posts-section-link";

import { action } from "@ember/object";
import { next } from "@ember/runloop";

const DEFAULT_SECTION_LINKS = [
  EverythingSectionLink,
  TrackedSectionLink,
  BookmarkedSectionLink,
  MyPostsSectionLink,
];

export default class SidebarTopicsSection extends GlimmerComponent {
  configuredSectionLinks = [...DEFAULT_SECTION_LINKS, ...customSectionLinks];

  sectionLinks = this.configuredSectionLinks.map((sectionLinkClass) => {
    return new sectionLinkClass({
      topicTrackingState: this.topicTrackingState,
      currentUser: this.currentUser,
      appEvents: this.appEvents,
    });
  });

  willDestroy() {
    this.sectionLinks.forEach((sectionLink) => sectionLink.teardown());
  }

  @action
  composeTopic() {
    const composerArgs = {
      action: Composer.CREATE_TOPIC,
      draftKey: Composer.NEW_TOPIC_KEY,
    };

    const controller = getOwner(this).lookup("controller:navigation/category");
    const category = controller.category;

    if (category && category.permission === PermissionType.FULL) {
      composerArgs.categoryId = category.id;
    }

    next(() => {
      getOwner(this).lookup("controller:composer").open(composerArgs);
    });
  }
}
