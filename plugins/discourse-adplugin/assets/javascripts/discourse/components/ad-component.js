/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { alias, or } from "@ember/object/computed";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { throwAjaxError } from "discourse/lib/ajax-error";
import discourseComputed from "discourse/lib/decorators";
import {
  isNthPost,
  isNthTopicListItem,
} from "discourse/plugins/discourse-adplugin/discourse/helpers/slot-position";

export default class AdComponent extends Component {
  @service router;
  @service session;

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
  @alias("router.currentRoute.name") currentRouteName;

  _impressionId = null;
  _clickTracked = false;

  _handleAdClick = () => {
    this.trackClick();
  };

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

  didInsertElement() {
    super.didInsertElement?.(...arguments);

    if (!this.get("showAd")) {
      return;
    }

    this.startVisibilityTracking();
    this.startClickTracking();
  }

  startClickTracking() {
    if (!this.siteSettings.ad_plugin_enable_tracking) {
      return;
    }

    this.element.addEventListener("click", this._handleAdClick);
  }

  async trackImpression() {
    const payload = this.buildImpressionPayload?.();
    if (!payload) {
      return;
    }

    try {
      const response = await ajax("/ad_plugin/ad_impressions", {
        type: "POST",
        data: JSON.stringify(payload),
        contentType: "application/json; charset=utf-8",
      });

      this._impressionId = response.id;
    } catch (e) {
      throwAjaxError(e);
    }
  }

  trackClick() {
    if (!this._impressionId || this._clickTracked) {
      return;
    }

    this._clickTracked = true;

    const url = `/ad_plugin/ad_impressions/${this._impressionId}`;

    if (navigator.sendBeacon && !this.site?.isTesting) {
      const formData = new FormData();
      formData.append("authenticity_token", this.session.csrfToken);
      navigator.sendBeacon(url, formData);
    } else {
      ajax(url, {
        type: "PATCH",
        contentType: "application/json; charset=utf-8",
      }).catch((e) => {
        // eslint-disable-next-line no-console
        console.error("Failed to track ad click:", e);
      });
    }
  }

  startVisibilityTracking() {
    if (!this.siteSettings.ad_plugin_enable_tracking) {
      return;
    }

    if ("IntersectionObserver" in window) {
      this._observer = new IntersectionObserver((entries) => {
        if (entries[0].isIntersecting) {
          this.trackImpression();
          this._observer.disconnect();
        }
      });
      this._observer.observe(this.element);
    } else {
      this.trackImpression();
    }
  }

  willDestroyElement() {
    super.willDestroyElement?.(...arguments);
    if (this._observer) {
      this._observer.disconnect();
    }
    if (this.element) {
      this.element.removeEventListener("click", this._handleAdClick);
    }
  }
}
