import Component from "@glimmer/component";
import { LinkTo } from "@ember/routing";
import { i18n } from "discourse-i18n";

export default class AISentimentDashboard extends Component {
  static shouldRender(_outletArgs, helper) {
    return helper.siteSettings.ai_sentiment_enabled;
  }

  <template>
    <li class="navigation-item sentiment">
      <LinkTo @route="admin.dashboardSentiment" class="navigation-link">
        {{i18n "discourse_ai.sentiments.dashboard.title"}}
      </LinkTo>
    </li>
  </template>
}
