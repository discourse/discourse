import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { service } from "@ember/service";
import bodyClass from "discourse/helpers/body-class";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";
import AiSearchDiscoveries from "../../components/ai-search-discoveries";
import AiSearchDiscoveriesTooltip from "../../components/ai-search-discoveries-tooltip";

export default class AiFullPageDiscobotDiscoveries extends Component {
  static shouldRender(args, { siteSettings, currentUser }) {
    return (
      siteSettings.ai_discover_enabled &&
      siteSettings.ai_discover_persona &&
      currentUser?.can_use_ai_discover_persona &&
      currentUser?.user_option?.ai_search_discoveries
    );
  }

  @service aiCredits;
  @service capabilities;
  @service discobotDiscoveries;

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
      <div class="ai-search-discoveries__discoveries-wrapper">
        {{#if this.discobotDiscoveries.showDiscoveryTitle}}
          <h3
            class="ai-search-discoveries__discoveries-title full-page-discoveries"
          >
            <span>
              {{icon "discobot"}}
              {{i18n "discourse_ai.discobot_discoveries.main_title"}}
            </span>
            <AiSearchDiscoveriesTooltip />
          </h3>
        {{/if}}

        <div class="full-page-discoveries">
          <AiSearchDiscoveries
            @discoveryPreviewLength={{this.previewLength}}
            @searchTerm={{@outletArgs.search}}
          />
        </div>
      </div>
    {{/if}}
  </template>
}
