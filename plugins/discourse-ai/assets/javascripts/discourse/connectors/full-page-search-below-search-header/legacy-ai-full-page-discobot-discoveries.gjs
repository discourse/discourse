import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { service } from "@ember/service";
import bodyClass from "discourse/helpers/body-class";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import LegacyAiSearchDiscoveries from "../../components/legacy-ai-search-discoveries";
import LegacyAiSearchDiscoveriesTooltip from "../../components/legacy-ai-search-discoveries-tooltip";

export default class LegacyAiFullPageDiscobotDiscoveries extends Component {
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
  @service capabilities;
  @service("legacy-discobot-discoveries") legacyDiscoveries;

  @tracked creditsAvailable = true;
  @tracked creditCheckComplete = false;

  constructor() {
    super(...arguments);
    this.#checkCredits();
  }

  async #checkCredits() {
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

  get previewLength() {
    if (!this.capabilities.viewport.md) {
      return 50;
    } else {
      return 10000;
    }
  }

  <template>
    {{#if this.shouldShow}}
      {{bodyClass "has-discoveries"}}
      <div
        class={{dConcatClass
          "ai-search-discoveries__discoveries-wrapper"
          (if this.legacyDiscoveries.showDiscoveryTitle "--has-content")
        }}
      >
        {{#if this.legacyDiscoveries.showDiscoveryTitle}}
          <h3
            class="ai-search-discoveries__discoveries-title full-page-discoveries"
          >
            <span>
              {{dIcon "far-discobot"}}
              {{i18n "discourse_ai.discobot_discoveries.legacy.main_title"}}
            </span>
            <LegacyAiSearchDiscoveriesTooltip />
          </h3>
        {{/if}}

        <div class="full-page-discoveries">
          <LegacyAiSearchDiscoveries
            @discoveryPreviewLength={{this.previewLength}}
            @searchTerm={{@outletArgs.search}}
          />
        </div>
      </div>
    {{/if}}
  </template>
}
