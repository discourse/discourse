import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { service } from "@ember/service";
import { eq } from "discourse/truth-helpers";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import AiDiscoveriesSearchOptions from "../../components/ai-discoveries-search-options";
import AiSearchDiscoveries from "../../components/ai-search-discoveries";

export default class AiDiscobotDiscoveries extends Component {
  static shouldRender(args, { siteSettings, currentUser }) {
    return (
      ["header", "welcome-banner"].includes(args?.location) &&
      siteSettings.ai_ask_ai_enabled &&
      siteSettings.ai_ask_ai_agent &&
      currentUser?.can_use_ask_ai
    );
  }

  @service aiCredits;
  @service discobotDiscoveries;

  @tracked creditsAvailable = true;
  @tracked creditCheckComplete = false;

  constructor() {
    super(...arguments);
    this._checkCredits();
  }

  async _checkCredits() {
    try {
      this.creditsAvailable =
        await this.aiCredits.isFeatureCreditAvailable("ask_ai");
    } catch {
      this.creditsAvailable = true;
    }
    this.creditCheckComplete = true;
  }

  get shouldShow() {
    return (
      this.creditCheckComplete &&
      this.creditsAvailable &&
      this.args.outletArgs.searchTerm &&
      this.discobotDiscoveries.lastQuery ===
        this.args.outletArgs.searchTerm.trim()
    );
  }

  get isGenerating() {
    return (
      this.discobotDiscoveries.loadingDiscoveries ||
      this.discobotDiscoveries.isStreaming
    );
  }

  <template>
    {{! rendered from here rather than its own connector so the options always
        lead the answer, whatever order connectors resolve in }}
    <AiDiscoveriesSearchOptions
      @triggerSearch={{@outletArgs.triggerSearch}}
      @updateTypeFilter={{@outletArgs.updateTypeFilter}}
      @searchTermChanged={{@outletArgs.searchTermChanged}}
      @clearTopicContext={{@outletArgs.clearTopicContext}}
      @searchTopics={{@outletArgs.searchTopics}}
      @openAdvancedSearch={{@outletArgs.openAdvancedSearch}}
      @inPMInboxContext={{@outletArgs.inPMInboxContext}}
      @clearPMInboxContext={{@outletArgs.clearPMInboxContext}}
    />

    {{#if this.shouldShow}}
      <div
        class={{dConcatClass
          "ai-discobot-discoveries"
          (if this.isGenerating "is-generating")
          (if this.discobotDiscoveries.sources.length "has-sources")
          (if (eq this.discobotDiscoveries.answerable false) "has-no-answer")
        }}
      >
        <AiSearchDiscoveries
          @searchTerm={{@outletArgs.searchTerm}}
          @closeSearchMenu={{@outletArgs.closeSearchMenu}}
          @showHeading={{true}}
          @showSources={{true}}
          @triggerOnInsert={{false}}
        />
      </div>
    {{/if}}
  </template>
}
