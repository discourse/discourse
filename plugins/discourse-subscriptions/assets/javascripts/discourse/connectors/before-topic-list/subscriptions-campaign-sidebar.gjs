import Component from "@ember/component";
import { classNames, tagName } from "@ember-decorators/component";
import CampaignBanner from "../../components/campaign-banner";

@tagName("div")
@classNames("before-topic-list-outlet", "subscriptions-campaign-sidebar")
export default class SubscriptionsCampaignSidebar extends Component {
  static shouldRender(args, context) {
    const { siteSettings } = context;
    const mobileView = context.site.mobileView;
    const bannerLocation =
      siteSettings.discourse_subscriptions_campaign_banner_location;
    return bannerLocation === "Sidebar" && !mobileView;
  }

  <template><CampaignBanner @connectorName="before-topic-list" /></template>
}
