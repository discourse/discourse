import Component from "@ember/component";
import { classNames, tagName } from "@ember-decorators/component";
import CampaignBanner from "../../components/campaign-banner";

@tagName("span")
@classNames(
  "after-topic-footer-buttons-outlet",
  "subscriptions-campaign-topic-footer"
)
export default class SubscriptionsCampaignTopicFooter extends Component {
  static shouldRender(args, context) {
    const { siteSettings } = context;
    const bannerLocation =
      siteSettings.discourse_subscriptions_campaign_banner_location;
    return bannerLocation === "Top" || bannerLocation === "Sidebar";
  }

  <template>
    <CampaignBanner @connectorName="after-topic-footer-buttons" />
  </template>
}
