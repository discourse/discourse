import Component from "@glimmer/component";
import CampaignBanner from "../../components/campaign-banner";

export default class SubscriptionsCampaignSidebar extends Component {
  static shouldRender(args, context) {
    const { siteSettings } = context;
    const mobileView = context.site.mobileView;
    const bannerLocation =
      siteSettings.discourse_subscriptions_campaign_banner_location;
    return bannerLocation === "Sidebar" && !mobileView;
  }

  <template>
    <div
      class="before-topic-list-outlet subscriptions-campaign-sidebar"
      ...attributes
    >
      <CampaignBanner @connectorName="before-topic-list" />
    </div>
  </template>
}
