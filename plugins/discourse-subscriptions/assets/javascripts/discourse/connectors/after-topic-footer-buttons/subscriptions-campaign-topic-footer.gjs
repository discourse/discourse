import Component from "@glimmer/component";
import CampaignBanner from "../../components/campaign-banner";

export default class SubscriptionsCampaignTopicFooter extends Component {
  static shouldRender(args, context) {
    const { siteSettings } = context;
    const bannerLocation =
      siteSettings.discourse_subscriptions_campaign_banner_location;
    return bannerLocation === "Top" || bannerLocation === "Sidebar";
  }

  <template>
    <span
      class="after-topic-footer-buttons-outlet subscriptions-campaign-topic-footer"
      ...attributes
    >
      <CampaignBanner @connectorName="after-topic-footer-buttons" />
    </span>
  </template>
}
