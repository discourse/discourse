import { htmlSafe } from "@ember/template";
import { isBlank } from "@ember/utils";
import {
  attributeBindings,
  classNameBindings,
  classNames,
} from "@ember-decorators/component";
import discourseComputed from "discourse/lib/decorators";
import AdComponent from "./ad-component";

const adIndex = {
  topic_list_top: null,
  topic_above_post_stream: null,
  topic_above_suggested: null,
  post_bottom: null,
  topic_list_between: null,
};

@classNames("house-creative")
@classNameBindings("adUnitClass")
@attributeBindings("colspanAttribute:colspan")
export default class HouseAd extends AdComponent {
  adHtml = "";
  currentAd = null;

  _handleAdClick = (event) => {
    // For house ads, only track clicks on <a> tags
    const link = event.target.closest("a");
    if (link && link.href) {
      this.trackClick();
    }
  };

  @discourseComputed
  colspanAttribute() {
    return this.tagName === "td" ? "5" : null;
  }

  @discourseComputed("placement", "showAd")
  adUnitClass(placement, showAd) {
    return showAd ? `house-${placement}` : "";
  }

  @discourseComputed(
    "showToGroups",
    "showAfterPost",
    "showAfterTopicListItem",
    "showOnCurrentPage"
  )
  showAd(
    showToGroups,
    showAfterPost,
    showAfterTopicListItem,
    showOnCurrentPage
  ) {
    return (
      showToGroups &&
      (showAfterPost || showAfterTopicListItem) &&
      showOnCurrentPage
    );
  }

  @discourseComputed("postNumber", "placement")
  showAfterPost(postNumber, placement) {
    if (!postNumber && placement !== "topic-list-between") {
      return true;
    }

    return this.isNthPost(
      parseInt(this.site.get("house_creatives.settings.after_nth_post"), 10)
    );
  }

  @discourseComputed("placement")
  showAfterTopicListItem(placement) {
    if (placement !== "topic-list-between") {
      return true;
    }

    return this.isNthTopicListItem(
      parseInt(this.site.get("house_creatives.settings.after_nth_topic"), 10)
    );
  }

  chooseAdHtml() {
    const houseAds = this.site.get("house_creatives"),
      placement = this.get("placement").replace(/-/g, "_"),
      adNames = this.adsNamesForSlot(placement);

    // filter out ads that should not be shown on the current page
    const filteredAds = adNames.filter((adName) => {
      const ad = houseAds.creatives[adName];
      if (!ad) {
        return false;
      }

      const hasCategoryScope = ad.category_ids?.length > 0;
      const hasRouteScope =
        this.siteSettings.ad_plugin_routes_enabled && ad.routes?.length > 0;

      // Global ad: no scopes
      if (!hasCategoryScope && !hasRouteScope) {
        return true;
      }

      // Scoped ad: match category or route
      const matchesCategory =
        hasCategoryScope && ad.category_ids.includes(this.currentCategoryId);
      const matchesRoute =
        hasRouteScope && ad.routes.includes(this.currentRouteName);
      return matchesCategory || matchesRoute;
    });
    if (filteredAds.length > 0) {
      if (!adIndex[placement]) {
        adIndex[placement] = 0;
      }
      let ad = houseAds.creatives[filteredAds[adIndex[placement]]] || "";
      adIndex[placement] = (adIndex[placement] + 1) % filteredAds.length;
      this.currentAd = ad || null;
      return ad.html;
    }

    this.currentAd = null;
  }

  adsNamesForSlot(placement) {
    const houseAds = this.site.get("house_creatives");

    if (!houseAds || !houseAds.settings) {
      return [];
    }

    const adsForSlot = houseAds.settings[placement];

    if (Object.keys(houseAds.creatives).length > 0 && !isBlank(adsForSlot)) {
      return adsForSlot.split("|");
    } else {
      return [];
    }
  }

  refreshAd() {
    this.set("adHtml", this.chooseAdHtml());
  }

  buildImpressionPayload() {
    return {
      ad_plugin_impression: {
        ad_type: this.site.ad_types.house,
        ad_plugin_house_ad_id: this.currentAd?.id,
        placement: this.placement,
      },
    };
  }

  didInsertElement() {
    super.didInsertElement(...arguments);

    if (!this.get("showAd")) {
      return;
    }

    if (adIndex.topic_list_top === null) {
      // start at a random spot in the ad inventory
      const houseAds = this.site.get("house_creatives");
      Object.keys(adIndex).forEach((placement) => {
        const adNames = this.adsNamesForSlot(placement);
        if (adNames.length === 0) {
          return;
        }
        // filter out ads that should not be shown on the current page
        const filteredAds = adNames.filter((adName) => {
          const ad = houseAds.creatives[adName];
          return (
            ad &&
            (!ad.category_ids?.length ||
              ad.category_ids.includes(this.currentCategoryId))
          );
        });
        adIndex[placement] = Math.floor(Math.random() * filteredAds.length);
      });
    }

    this.refreshAd();
  }

  <template>
    {{#if this.showAd}}
      {{htmlSafe this.adHtml}}
    {{/if}}
  </template>
}
