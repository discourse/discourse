import Component from "@glimmer/component";
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

  @service discobotDiscoveries;

  get shouldShow() {
    return (
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
      @clearPMInboxContext={{@outletArgs.clearPMInboxContext}}
      @clearTopicContext={{@outletArgs.clearTopicContext}}
      @inPMInboxContext={{@outletArgs.inPMInboxContext}}
      @openAdvancedSearch={{@outletArgs.openAdvancedSearch}}
      @searchTermChanged={{@outletArgs.searchTermChanged}}
      @searchTopics={{@outletArgs.searchTopics}}
      @triggerSearch={{@outletArgs.triggerSearch}}
      @updateTypeFilter={{@outletArgs.updateTypeFilter}}
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
          @closeSearchMenu={{@outletArgs.closeSearchMenu}}
          @searchTerm={{@outletArgs.searchTerm}}
          @showHeading={{true}}
          @showSources={{true}}
          @triggerOnInsert={{false}}
        />
      </div>
    {{/if}}
  </template>
}
