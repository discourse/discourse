import Component from "@ember/component";
import { classNames, tagName } from "@ember-decorators/component";
import CampaignBanner from "../../components/campaign-banner";

@tagName("div")
@classNames("above-main-container-outlet", "subscriptions-campaign")
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

  <template><CampaignBanner @connectorName="above-main-container" /></template>
}
