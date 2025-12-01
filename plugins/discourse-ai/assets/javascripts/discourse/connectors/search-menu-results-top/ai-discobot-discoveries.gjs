import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { service } from "@ember/service";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";
import AiSearchDiscoveries from "../../components/ai-search-discoveries";
import AiSearchDiscoveriesTooltip from "../../components/ai-search-discoveries-tooltip";

export default class AiDiscobotDiscoveries extends Component {
  static shouldRender(args, { siteSettings, currentUser }) {
    return (
      siteSettings.ai_discover_enabled &&
      siteSettings.ai_discover_persona &&
      currentUser?.can_use_ai_discover_persona &&
      currentUser?.user_option?.ai_search_discoveries
    );
  }

  @service aiCredits;
  @service discobotDiscoveries;
  @service search;

  @tracked creditsAvailable = true;
  @tracked creditCheckComplete = false;

  constructor() {
    super(...arguments);
    this._checkCredits();
  }

  async _checkCredits() {
    try {
      this.creditsAvailable =
        await this.aiCredits.isFeatureCreditAvailable("discoveries");
    } catch {
      this.creditsAvailable = true;
    }
    this.creditCheckComplete = true;
  }

  get shouldShow() {
    return this.creditCheckComplete && this.creditsAvailable;
  }

  <template>
    {{#if this.shouldShow}}
      <div class="ai-discobot-discoveries">
        {{#if this.discobotDiscoveries.showDiscoveryTitle}}
          <h3 class="ai-search-discoveries__discoveries-title">
            <span>
              {{icon "discobot"}}
              {{i18n "discourse_ai.discobot_discoveries.main_title"}}
            </span>

            <AiSearchDiscoveriesTooltip />
          </h3>
        {{/if}}

        <AiSearchDiscoveries
          @searchTerm={{@outletArgs.searchTerm}}
          @discoveryPreviewLength={{50}}
          @closeSearchMenu={{@outletArgs.closeSearchMenu}}
        />

        {{#if this.search.results.topics.length}}
          <h3 class="ai-search-discoveries__regular-results-title">
            {{icon "bars-staggered"}}
            {{i18n "discourse_ai.discobot_discoveries.regular_results"}}
          </h3>
        {{/if}}
      </div>
    {{/if}}
  </template>
}
