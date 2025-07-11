import { scheduleOnce } from "@ember/runloop";
import { htmlSafe } from "@ember/template";
import { classNameBindings } from "@ember-decorators/component";
import RSVP from "rsvp";
import discourseComputed from "discourse/lib/decorators";
import { isTesting } from "discourse/lib/environment";
import loadScript from "discourse/lib/load-script";
import { i18n } from "discourse-i18n";
import AdComponent from "./ad-component";

let _loaded = false,
  _promise = null,
  renderCounts = {};

function parseAdWidth(value) {
  if (value === "responsive") {
    return "auto";
  }
  if (value.startsWith("fluid")) {
    return "fluid";
  }
  const w = parseInt(value.substring(0, 3).trim(), 10);
  if (isNaN(w)) {
    return "auto";
  } else {
    return `${w}px`;
  }
}

function parseAdHeight(value) {
  if (value === "responsive") {
    return "auto";
  }
  if (value.startsWith("fluid")) {
    return "fluid";
  }
  const h = parseInt(value.substring(4, 7).trim(), 10);
  if (isNaN(h)) {
    return "auto";
  } else {
    return `${h}px`;
  }
}

function loadAdsense() {
  if (_loaded) {
    return RSVP.resolve();
  }

  if (_promise) {
    return _promise;
  }

  const adsenseSrc =
    ("https:" === document.location.protocol ? "https:" : "http:") +
    "//pagead2.googlesyndication.com/pagead/js/adsbygoogle.js";
  _promise = loadScript(adsenseSrc, { scriptTag: true }).then(function () {
    _loaded = true;
  });

  return _promise;
}

const DESKTOP_SETTINGS = {
  "topic-list-top": {
    code: "adsense_topic_list_top_code",
    sizes: "adsense_topic_list_top_ad_sizes",
  },
  "topic-above-post-stream": {
    code: "adsense_topic_above_post_stream_code",
    sizes: "adsense_topic_above_post_stream_ad_sizes",
  },
  "topic-above-suggested": {
    code: "adsense_topic_above_suggested_code",
    sizes: "adsense_topic_above_suggested_ad_sizes",
  },
  "post-bottom": {
    code: "adsense_post_bottom_code",
    sizes: "adsense_post_bottom_ad_sizes",
  },
};

const MOBILE_SETTINGS = {
  "topic-list-top": {
    code: "adsense_mobile_topic_list_top_code",
    sizes: "adsense_mobile_topic_list_top_ad_size",
  },
  "topic-above-post-stream": {
    code: "adsense_mobile_topic_above_post_stream_code",
    sizes: "adsense_mobile_topic_above_post_stream_ad_size",
  },
  "topic-above-suggested": {
    code: "adsense_mobile_topic_above_suggested_code",
    sizes: "adsense_mobile_topic_above_suggested_ad_size",
  },
  "post-bottom": {
    code: "adsense_mobile_post_bottom_code",
    sizes: "adsense_mobile_post_bottom_ad_size",
  },
};

@classNameBindings(
  ":google-adsense",
  "classForSlot",
  "isResponsive:adsense-responsive"
)
export default class GoogleAdsense extends AdComponent {
  loadedGoogletag = false;
  publisher_id = null;
  ad_width = null;
  ad_height = null;
  adRequested = false;

  init() {
    let config, size;
    const placement = this.get("placement");

    if (this.site.mobileView) {
      config = MOBILE_SETTINGS[placement];
    } else {
      config = DESKTOP_SETTINGS[placement];
    }

    if (!renderCounts[placement]) {
      renderCounts[placement] = 0;
    }

    const sizes = (this.siteSettings[config.sizes] || "").split("|");

    if (sizes.length === 1) {
      size = sizes[0];
    } else {
      size = sizes[renderCounts[placement] % sizes.length];
      renderCounts[placement] += 1;
    }

    this.set("ad_width", parseAdWidth(size));
    this.set("ad_height", parseAdHeight(size));
    this.set("ad_code", this.siteSettings[config.code]);
    this.set("publisher_id", this.siteSettings.adsense_publisher_code);
    super.init();
  }

  async _triggerAds() {
    if (isTesting()) {
      return; // Don't load external JS during tests
    }

    this.set("adRequested", true);

    await loadAdsense();

    if (this.isDestroyed || this.isDestroying) {
      // Component removed from DOM before script loaded
      return;
    }

    try {
      const adsbygoogle = (window.adsbygoogle ||= []);
      adsbygoogle.push({}); // ask AdSense to fill one ad unit
    } catch (ex) {
      // eslint-disable-next-line no-console
      console.error("Adsense error:", ex);
    }
  }

  didInsertElement() {
    super.didInsertElement();

    if (!this.get("showAd")) {
      return;
    }

    scheduleOnce("afterRender", this, this._triggerAds);
  }

  @discourseComputed("ad_width")
  isResponsive(adWidth) {
    return ["auto", "fluid"].includes(adWidth);
  }

  @discourseComputed("ad_width")
  isFluid(adWidth) {
    return adWidth === "fluid";
  }

  @discourseComputed("placement", "showAd")
  classForSlot(placement, showAd) {
    return showAd ? htmlSafe(`adsense-${placement}`) : "";
  }

  @discourseComputed("isResponsive", "isFluid")
  autoAdFormat(isResponsive, isFluid) {
    return isResponsive ? htmlSafe(isFluid ? "fluid" : "auto") : false;
  }

  @discourseComputed("ad_width", "ad_height", "isResponsive")
  adWrapperStyle(w, h, isResponsive) {
    return htmlSafe(isResponsive ? "" : `width: ${w}; height: ${h};`);
  }

  @discourseComputed("adWrapperStyle", "isResponsive")
  adInsStyle(adWrapperStyle, isResponsive) {
    return htmlSafe(
      `display: ${isResponsive ? "block" : "inline-block"}; ${adWrapperStyle}`
    );
  }

  @discourseComputed
  showAdsenseAds() {
    if (!this.currentUser) {
      return true;
    }

    return this.currentUser.show_adsense_ads;
  }

  @discourseComputed(
    "publisher_id",
    "showAdsenseAds",
    "showToGroups",
    "showAfterPost",
    "showOnCurrentPage"
  )
  showAd(
    publisherId,
    showAdsenseAds,
    showToGroups,
    showAfterPost,
    showOnCurrentPage
  ) {
    return (
      publisherId &&
      showAdsenseAds &&
      showToGroups &&
      showAfterPost &&
      showOnCurrentPage
    );
  }

  @discourseComputed("postNumber")
  showAfterPost(postNumber) {
    if (!postNumber) {
      return true;
    }

    return this.isNthPost(
      parseInt(this.siteSettings.adsense_nth_post_code, 10)
    );
  }

  <template>
    {{#if this.showAd}}
      <div class="google-adsense-label"><h2>{{i18n
            "adplugin.advertisement_label"
          }}</h2></div>
      <div
        class="google-adsense-content"
        id={{if this.isResponsive "google-adsense__responsive"}}
        style={{this.adWrapperStyle}}
      >
        <ins
          class="adsbygoogle"
          style={{this.adInsStyle}}
          data-ad-client="ca-pub-{{this.publisher_id}}"
          data-ad-slot={{this.ad_code}}
          data-ad-format={{this.autoAdFormat}}
        >
        </ins>
      </div>
    {{/if}}
  </template>
}
