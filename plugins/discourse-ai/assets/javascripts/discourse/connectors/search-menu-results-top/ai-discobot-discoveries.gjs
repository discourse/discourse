import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { service } from "@ember/service";
import { eq } from "discourse/truth-helpers";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import AiSearchDiscoveries from "../../components/ai-search-discoveries";

export default class AiDiscobotDiscoveries extends Component {
  static shouldRender(args, { siteSettings, currentUser }) {
    return (
      ["header", "welcome-banner"].includes(args?.location) &&
      siteSettings.ai_discover_enabled &&
      siteSettings.ai_discover_agent &&
      currentUser?.can_use_ai_discover_agent &&
      currentUser?.user_option?.ai_search_discoveries
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
        await this.aiCredits.isFeatureCreditAvailable("discoveries");
    } catch {
      this.creditsAvailable = true;
    }
    this.creditCheckComplete = true;
  }

  get shouldShow() {
    return (
      this.creditCheckComplete &&
      this.creditsAvailable &&
      this.discobotDiscoveries.mode === "ask" &&
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
