import { computed } from "@ember/object";
import { htmlSafe } from "@ember/template";
import AdComponent from "./ad-component";

export default class CarbonadsAd extends AdComponent {
  serve_id = null;
  placement = null;

  init() {
    this.set("serve_id", this.siteSettings.carbonads_serve_id);
    this.set("placement", this.siteSettings.carbonads_placement);
    super.init();
  }

  @computed("serve_id", "placement")
  get url() {
    return htmlSafe(
      `//cdn.carbonads.com/carbon.js?serve=${this.serve_id}&placement=${this.placement}`
    );
  }

  @computed
  get showCarbonAds() {
    if (!this.currentUser) {
      return true;
    }

    return this.currentUser.show_carbon_ads;
  }

  @computed(
    "placement",
    "serve_id",
    "showCarbonAds",
    "showToGroups",
    "showOnCurrentPage"
  )
  get showAd() {
    return (
      this.placement && this.serve_id && this.showCarbonAds && this.showToGroups && this.showOnCurrentPage
    );
  }

  buildImpressionPayload() {
    return {
      ad_plugin_impression: {
        ad_type: this.site.ad_types.carbon,
        ad_plugin_house_ad_id: null,
        placement: this.placement,
      },
    };
  }

  <template>
    {{#if this.showAd}}
      {{! template-lint-disable no-forbidden-elements }}
      <script src={{this.url}} id="_carbonads_js" async type="text/javascript">
      </script>
    {{/if}}
  </template>
}
