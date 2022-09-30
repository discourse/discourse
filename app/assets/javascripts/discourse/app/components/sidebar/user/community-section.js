import I18n from "I18n";

import { bind } from "discourse-common/utils/decorators";
import Composer from "discourse/models/composer";
import { getOwner } from "discourse-common/lib/get-owner";
import PermissionType from "discourse/models/permission-type";
import EverythingSectionLink from "discourse/lib/sidebar/common/community-section/everything-section-link";
import TrackedSectionLink from "discourse/lib/sidebar/user/community-section/tracked-section-link";
import MyPostsSectionLink from "discourse/lib/sidebar/user/community-section/my-posts-section-link";
import GroupsSectionLink from "discourse/lib/sidebar/common/community-section/groups-section-link";
import UsersSectionLink from "discourse/lib/sidebar/common/community-section/users-section-link";
import AboutSectionLink from "discourse/lib/sidebar/common/community-section/about-section-link";
import FAQSectionLink from "discourse/lib/sidebar/common/community-section/faq-section-link";
import AdminSectionLink from "discourse/lib/sidebar/user/community-section/admin-section-link";
import BadgesSectionLink from "discourse/lib/sidebar/common/community-section/badges-section-link";
import ReviewSectionLink from "discourse/lib/sidebar/user/community-section/review-section-link";
import SidebarCommonCommunitySection from "discourse/components/sidebar/common/community-section";

import { action } from "@ember/object";
import { next } from "@ember/runloop";

export default class SidebarUserCommunitySection extends SidebarCommonCommunitySection {
  constructor() {
    super(...arguments);

    this.headerActionsIcon = "plus";

    this.headerActions = [
      {
        action: this.composeTopic,
        title: I18n.t("sidebar.sections.community.header_action_title"),
      },
    ];

    this.appEvents.on(
      "user-reviewable-count:changed",
      this._refreshSectionLinks
    );
  }

  willDestroy() {
    super.willDestroy(...arguments);

    this.appEvents.off(
      "user-reviewable-count:changed",
      this._refreshSectionLinks
    );
  }

  @bind
  _refreshSectionLinks() {
    return this.refreshSectionLinks();
  }

  get defaultMainSectionLinks() {
    const links = [
      EverythingSectionLink,
      TrackedSectionLink,
      MyPostsSectionLink,
      AdminSectionLink,
    ];

    if (this.currentUser.reviewable_count > 0) {
      links.push(ReviewSectionLink);
    }

    return links;
  }

  get defaultMoreSectionLinks() {
    const links = [GroupsSectionLink, UsersSectionLink, BadgesSectionLink];

    if (this.currentUser.reviewable_count === 0) {
      links.push(ReviewSectionLink);
    }

    return links;
  }

  get defaultMoreSecondarySectionLinks() {
    return [AboutSectionLink, FAQSectionLink];
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
