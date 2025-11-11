import { alias } from "@ember/object/computed";
import { htmlSafe } from "@ember/template";
import { classNameBindings, classNames } from "@ember-decorators/component";
import { on } from "@ember-decorators/object";
import RSVP from "rsvp";
import discourseComputed from "discourse/lib/decorators";
import { isTesting } from "discourse/lib/environment";
import loadScript from "discourse/lib/load-script";
import { i18n } from "discourse-i18n";
import AdComponent from "./ad-component";

let _loaded = false,
  _promise = null,
  ads = {},
  nextSlotNum = 1,
  renderCounts = {};

function getNextSlotNum() {
  return nextSlotNum++;
}

function splitWidthInt(value) {
  let str = value.substring(0, 3);
  return str.trim();
}

function splitHeightInt(value) {
  let str = value.substring(4, 7);
  return str.trim();
}

// This creates an array for the values of the custom targeting key
function valueParse(value) {
  let final = value.replace(/ /g, "");
  final = final.replace(/['"]+/g, "");
  final = final.split(",");
  return final;
}

// This creates an array for the key of the custom targeting key
function keyParse(word) {
  let key = word;
  key = key.replace(/['"]+/g, "");
  key = key.split("\n");
  return key;
}

// This should call adslot.setTargeting(key for that location, value for that location)
function custom_targeting(key_array, value_array, adSlot) {
  for (let i = 0; i < key_array.length; i++) {
    if (key_array[i]) {
      adSlot.setTargeting(key_array[i], valueParse(value_array[i]));
    }
  }
}

const DESKTOP_SETTINGS = {
  "topic-list-top": {
    code: "dfp_topic_list_top_code",
    sizes: "dfp_topic_list_top_ad_sizes",
    targeting_keys: "dfp_target_topic_list_top_key_code",
    targeting_values: "dfp_target_topic_list_top_value_code",
  },
  "topic-above-post-stream": {
    code: "dfp_topic_above_post_stream_code",
    sizes: "dfp_topic_above_post_stream_ad_sizes",
    targeting_keys: "dfp_target_topic_above_post_stream_key_code",
    targeting_values: "dfp_target_topic_above_post_stream_value_code",
  },
  "topic-above-suggested": {
    code: "dfp_topic_above_suggested_code",
    sizes: "dfp_topic_above_suggested_ad_sizes",
    targeting_keys: "dfp_target_topic_above_suggested_key_code",
    targeting_values: "dfp_target_topic_above_suggested_value_code",
  },
  "post-bottom": {
    code: "dfp_post_bottom_code",
    sizes: "dfp_post_bottom_ad_sizes",
    targeting_keys: "dfp_target_post_bottom_key_code",
    targeting_values: "dfp_target_post_bottom_value_code",
  },
};

const MOBILE_SETTINGS = {
  "topic-list-top": {
    code: "dfp_mobile_topic_list_top_code",
    sizes: "dfp_mobile_topic_list_top_ad_sizes",
    targeting_keys: "dfp_target_topic_list_top_key_code",
    targeting_values: "dfp_target_topic_list_top_value_code",
  },
  "topic-above-post-stream": {
    code: "dfp_mobile_topic_above_post_stream_code",
    sizes: "dfp_mobile_topic_above_post_stream_ad_sizes",
    targeting_keys: "dfp_target_topic_above_post_stream_key_code",
    targeting_values: "dfp_target_topic_above_post_stream_value_code",
  },
  "topic-above-suggested": {
    code: "dfp_mobile_topic_above_suggested_code",
    sizes: "dfp_mobile_topic_above_suggested_ad_sizes",
    targeting_keys: "dfp_target_topic_above_suggested_key_code",
    targeting_values: "dfp_target_topic_above_suggested_value_code",
  },
  "post-bottom": {
    code: "dfp_mobile_post_bottom_code",
    sizes: "dfp_mobile_post_bottom_ad_sizes",
    targeting_keys: "dfp_target_post_bottom_key_code",
    targeting_values: "dfp_target_post_bottom_value_code",
  },
};

function getWidthAndHeight(placement, settings, isMobile) {
  let config, size;

  if (isMobile) {
    config = MOBILE_SETTINGS[placement];
  } else {
    config = DESKTOP_SETTINGS[placement];
  }

  if (!renderCounts[placement]) {
    renderCounts[placement] = 0;
  }

  const sizes = (settings[config.sizes] || "").split("|");

  if (sizes.length === 1) {
    size = sizes[0];
  } else {
    size = sizes[renderCounts[placement] % sizes.length];
    renderCounts[placement] += 1;
  }

  if (size === "fluid") {
    return { width: "fluid", height: "fluid" };
  }

  const sizeObj = {
    width: parseInt(splitWidthInt(size), 10),
    height: parseInt(splitHeightInt(size), 10),
  };

  if (!isNaN(sizeObj.width) && !isNaN(sizeObj.height)) {
    return sizeObj;
  }
}

function defineSlot(
  divId,
  placement,
  settings,
  isMobile,
  width,
  height,
  categoryTarget
) {
  if (!settings.dfp_publisher_id) {
    return;
  }

  if (ads[divId]) {
    return ads[divId];
  }

  let ad, config, publisherId;

  if (isMobile) {
    publisherId = settings.dfp_publisher_id_mobile || settings.dfp_publisher_id;
    config = MOBILE_SETTINGS[placement];
  } else {
    publisherId = settings.dfp_publisher_id;
    config = DESKTOP_SETTINGS[placement];
  }

  ad = window.googletag.defineSlot(
    "/" + publisherId + "/" + settings[config.code],
    [width, height],
    divId
  );

  custom_targeting(
    keyParse(settings[config.targeting_keys]),
    keyParse(settings[config.targeting_values]),
    ad
  );

  if (categoryTarget) {
    ad.setTargeting("discourse-category", categoryTarget);
  }

  ad.addService(window.googletag.pubads());

  ads[divId] = { ad, width, height };
  return ads[divId];
}

function destroySlot(divId) {
  if (ads[divId] && window.googletag) {
    window.googletag.destroySlots([ads[divId].ad]);
    delete ads[divId];
  }
}

function loadGoogle() {
  /**
   * Refer to this article for help:
   * https://support.google.com/admanager/answer/4578089?hl=en
   */

  if (_loaded) {
    return RSVP.resolve();
  }

  if (_promise) {
    return _promise;
  }

  // The boilerplate code
  let dfpSrc =
    ("https:" === document.location.protocol ? "https:" : "http:") +
    "//securepubads.g.doubleclick.net/tag/js/gpt.js";
  _promise = loadScript(dfpSrc, { scriptTag: true }).then(function () {
    _loaded = true;
    if (window.googletag === undefined) {
      // eslint-disable-next-line no-console
      console.log("googletag is undefined!");
    }

    window.googletag.cmd.push(function () {
      // Infinite scroll requires SRA:
      window.googletag.pubads().enableSingleRequest();

      // we always use refresh() to fetch the ads:
      window.googletag.pubads().disableInitialLoad();

      // Improve CSP compatibility (https://developers.google.com/publisher-tag/guides/content-security-policy)
      window.googletag.pubads().setForceSafeFrame(true);

      window.googletag.enableServices();
    });
  });

  window.googletag = window.googletag || { cmd: [] };

  return _promise;
}

@classNameBindings("adUnitClass")
@classNames("google-dfp-ad")
export default class GoogleDfpAd extends AdComponent {
  loadedGoogletag = false;
  lastAdRefresh = null;

  @alias("size.width") width;

  @alias("size.height") height;

  @discourseComputed
  size() {
    return getWidthAndHeight(
      this.get("placement"),
      this.siteSettings,
      this.site.mobileView
    );
  }

  @discourseComputed(
    "siteSettings.dfp_publisher_id",
    "siteSettings.dfp_publisher_id_mobile",
    "site.mobileView"
  )
  publisherId(globalId, mobileId, isMobile) {
    if (isMobile) {
      return mobileId || globalId;
    } else {
      return globalId;
    }
  }

  @discourseComputed("placement", "postNumber")
  divId(placement, postNumber) {
    let slotNum = getNextSlotNum();
    if (postNumber) {
      return `div-gpt-ad-${slotNum}-${placement}-${postNumber}`;
    } else {
      return `div-gpt-ad-${slotNum}-${placement}`;
    }
  }

  @discourseComputed("placement", "showAd")
  adUnitClass(placement, showAd) {
    return showAd ? `dfp-ad-${placement}` : "";
  }

  @discourseComputed("width", "height")
  adWrapperStyle(w, h) {
    if (w !== "fluid") {
      return htmlSafe(`width: ${w}px; height: ${h}px;`);
    }
  }

  @discourseComputed("width")
  adTitleStyleMobile(w) {
    if (w !== "fluid") {
      return htmlSafe(`width: ${w}px;`);
    }
  }

  @discourseComputed(
    "publisherId",
    "showDfpAds",
    "showToGroups",
    "showAfterPost",
    "showOnCurrentPage",
    "size"
  )
  showAd(
    publisherId,
    showDfpAds,
    showToGroups,
    showAfterPost,
    showOnCurrentPage,
    size
  ) {
    return (
      publisherId &&
      showDfpAds &&
      showToGroups &&
      showAfterPost &&
      showOnCurrentPage &&
      size
    );
  }

  @discourseComputed
  showDfpAds() {
    if (!this.currentUser) {
      return true;
    }

    return this.currentUser.show_dfp_ads;
  }

  @discourseComputed("postNumber")
  showAfterPost(postNumber) {
    if (!postNumber) {
      return true;
    }

    return this.isNthPost(parseInt(this.siteSettings.dfp_nth_post_code, 10));
  }

  // 3 second delay between calls to refresh ads in a component.
  // Ember often calls updated() more than once, and *sometimes*
  // updated() is called after _initGoogleDFP().
  shouldRefreshAd() {
    const lastAdRefresh = this.get("lastAdRefresh");
    if (!lastAdRefresh) {
      return true;
    }
    return new Date() - lastAdRefresh > 3000;
  }

  @on("didUpdate")
  updated() {
    if (!this.shouldRefreshAd()) {
      return;
    }

    let slot = ads[this.get("divId")];
    if (!(slot && slot.ad)) {
      return;
    }

    let ad = slot.ad,
      categorySlug = this.get("currentCategorySlug");

    if (this.get("loadedGoogletag")) {
      this.set("lastAdRefresh", new Date());
      window.googletag.cmd.push(() => {
        ad.setTargeting("discourse-category", categorySlug || "0");
        window.googletag.pubads().refresh([ad]);
      });
    }
  }

  @on("didInsertElement")
  _initGoogleDFP() {
    if (isTesting()) {
      return; // Don't load external JS during tests
    }

    if (!this.get("showAd")) {
      return;
    }

    loadGoogle().then(() => {
      this.set("loadedGoogletag", true);
      this.set("lastAdRefresh", new Date());

      window.googletag.cmd.push(() => {
        let slot = defineSlot(
          this.get("divId"),
          this.get("placement"),
          this.siteSettings,
          this.site.mobileView,
          this.get("width"),
          this.get("height"),
          this.get("currentCategorySlug") || "0"
        );
        if (slot && slot.ad) {
          // Display has to be called before refresh
          // and after the slot div is in the page.
          window.googletag.display(this.get("divId"));
          window.googletag.pubads().refresh([slot.ad]);
        }
      });
    });
  }

  willRender() {
    super.willRender(...arguments);

    if (!this.get("showAd")) {
      return;
    }
  }

  @on("willDestroyElement")
  cleanup() {
    destroySlot(this.get("divId"));
  }

  <template>
    {{#if this.showAd}}
      {{#if this.site.mobileView}}
        <div class="google-dfp-ad-label" style={{this.adTitleStyleMobile}}><h2
          >{{i18n "adplugin.advertisement_label"}}</h2></div>
        <div
          id={{this.divId}}
          style={{this.adWrapperStyle}}
          class="dfp-ad-unit"
          align="center"
        ></div>
      {{else}}
        <div class="google-dfp-ad-label"><h2>{{i18n
              "adplugin.advertisement_label"
            }}</h2></div>
        <div
          id={{this.divId}}
          style={{this.adWrapperStyle}}
          class="dfp-ad-unit"
          align="center"
        ></div>
      {{/if}}
    {{/if}}
  </template>
}
