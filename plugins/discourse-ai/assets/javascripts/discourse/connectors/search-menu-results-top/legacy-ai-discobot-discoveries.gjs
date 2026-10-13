import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { service } from "@ember/service";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import LegacyAiSearchDiscoveries from "../../components/legacy-ai-search-discoveries";
import LegacyAiSearchDiscoveriesTooltip from "../../components/legacy-ai-search-discoveries-tooltip";

export default class LegacyAiDiscobotDiscoveries extends Component {
  static shouldRender(args, { siteSettings, currentUser }) {
    const askAiAvailable =
      siteSettings.ai_ask_ai_enabled && currentUser?.can_use_ask_ai;

    return (
      !askAiAvailable &&
      siteSettings.ai_discover_enabled &&
      siteSettings.ai_discover_agent &&
      currentUser?.can_use_ai_discover_agent &&
      currentUser?.user_option?.ai_search_discoveries !== false
    );
  }

  @service aiCredits;
  @service("legacy-discobot-discoveries") legacyDiscoveries;
  @service search;

  @tracked creditsAvailable = true;
  @tracked creditCheckComplete = false;

  constructor() {
    super(...arguments);
    this._checkCredits();
  }

  get shouldShow() {
    return this.creditCheckComplete && this.creditsAvailable;
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

  <template>
    {{#if this.shouldShow}}
      <div class="ai-discobot-discoveries">
        {{#if this.legacyDiscoveries.showDiscoveryTitle}}
          <h3 class="ai-search-discoveries__discoveries-title">
            <span>
              {{dIcon "far-discobot"}}
              {{i18n "discourse_ai.discobot_discoveries.legacy.main_title"}}
            </span>

            <LegacyAiSearchDiscoveriesTooltip />
          </h3>
        {{/if}}

        <LegacyAiSearchDiscoveries
          @closeSearchMenu={{@outletArgs.closeSearchMenu}}
          @discoveryPreviewLength={{50}}
          @searchTerm={{@outletArgs.searchTerm}}
        />

        {{#if this.search.results.topics.length}}
          <h3 class="ai-search-discoveries__regular-results-title">
            {{dIcon "bars-staggered"}}
            {{i18n "discourse_ai.discobot_discoveries.legacy.regular_results"}}
          </h3>
        {{/if}}
      </div>
    {{/if}}
  </template>
}
