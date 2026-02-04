/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { tagName } from "@ember-decorators/component";
import CampaignBanner from "../../components/campaign-banner";

@tagName("")
export default class SubscriptionsCampaign extends Component {
  static shouldRender(args, context) {
    const { siteSettings } = context;
    const mobileView = context.site.mobileView;
    const bannerLocation =
      siteSettings.discourse_subscriptions_campaign_banner_location;
    return (
      bannerLocation === "Top" || (bannerLocation === "Sidebar" && mobileView)
    );
  }

  <template>
    <div
      class="above-main-container-outlet subscriptions-campaign"
      ...attributes
    >
      <CampaignBanner @connectorName="above-main-container" />
    </div>
  </template>
}
