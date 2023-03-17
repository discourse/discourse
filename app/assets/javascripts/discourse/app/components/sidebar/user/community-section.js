import I18n from "I18n";

import Composer from "discourse/models/composer";
import { getOwner } from "discourse-common/lib/get-owner";
import PermissionType from "discourse/models/permission-type";
import EverythingSectionLink from "discourse/lib/sidebar/common/community-section/everything-section-link";
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
import { inject as service } from "@ember/service";

export default class SidebarUserCommunitySection extends SidebarCommonCommunitySection {
  @service composer;

  constructor() {
    super(...arguments);

    this.headerActionsIcon = "plus";

    this.headerActions = [
      {
        action: this.composeTopic,
        title: I18n.t("sidebar.sections.community.header_action_title"),
      },
    ];
  }

  get defaultMainSectionLinks() {
    return [
      EverythingSectionLink,
      MyPostsSectionLink,
      AdminSectionLink,
      ReviewSectionLink,
    ];
  }

  get defaultMoreSectionLinks() {
    return [
      GroupsSectionLink,
      UsersSectionLink,
      BadgesSectionLink,
      ReviewSectionLink,
    ];
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
      this.composer.open(composerArgs);
    });
  }
}
