import Component from "@ember/component";
import { alias, or } from "@ember/object/computed";
import { service } from "@ember/service";
import discourseComputed from "discourse/lib/decorators";
import {
  isNthPost,
  isNthTopicListItem,
} from "discourse/plugins/discourse-adplugin/discourse/helpers/slot-position";

export default class AdComponent extends Component {
  @service router;

  @or(
    "router.currentRoute.attributes.category.id",
    "router.currentRoute.parent.attributes.category_id"
  )
  currentCategoryId;

  @or(
    "router.currentRoute.attributes.category.slug",
    "router.currentRoute.parent.attributes.category.slug"
  )
  currentCategorySlug;

  // Server needs to compute this in case hidden tags are being used.
  @alias("router.currentRoute.parent.attributes.tags_disable_ads")
  topicTagsDisableAds;

  @or(
    "router.currentRoute.attributes.category.read_restricted",
    "router.currentRoute.parent.attributes.category.read_restricted"
  )
  isRestrictedCategory;

  @discourseComputed(
    "router.currentRoute.attributes.__type",
    "router.currentRoute.attributes.id"
  )
  topicListTag(type, tag) {
    if (type === "tag" && tag) {
      return tag;
    }
  }

  @discourseComputed("router.currentRoute.parent.attributes.archetype")
  isPersonalMessage(topicType) {
    return topicType === "private_message";
  }

  @discourseComputed
  showToGroups() {
    if (!this.currentUser) {
      return true;
    }

    return this.currentUser.show_to_groups;
  }

  @discourseComputed(
    "currentCategoryId",
    "topicTagsDisableAds",
    "topicListTag",
    "isPersonalMessage",
    "isRestrictedCategory"
  )
  showOnCurrentPage(
    categoryId,
    topicTagsDisableAds,
    topicListTag,
    isPersonalMessage,
    isRestrictedCategory
  ) {
    return (
      !topicTagsDisableAds &&
      (!categoryId ||
        !this.siteSettings.no_ads_for_categories ||
        !this.siteSettings.no_ads_for_categories
          .split("|")
          .includes(categoryId.toString())) &&
      (!topicListTag ||
        !this.siteSettings.no_ads_for_tags ||
        !this.siteSettings.no_ads_for_tags.split("|").includes(topicListTag)) &&
      (!isPersonalMessage || !this.siteSettings.no_ads_for_personal_messages) &&
      (!isRestrictedCategory ||
        !this.siteSettings.no_ads_for_restricted_categories)
    );
  }

  isNthPost(n) {
    return isNthPost(n, this.get("postNumber"));
  }

  isNthTopicListItem(n) {
    return isNthTopicListItem(n, this.get("indexNumber"));
  }
}
