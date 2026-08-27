import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { service } from "@ember/service";
import bodyClass from "discourse/helpers/body-class";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import AiSearchDiscoveries from "../../components/ai-search-discoveries";
import { SEARCH_TYPE_ASK_AI } from "../../lib/full-page-search-types";

export default class AiFullPageDiscobotDiscoveries extends Component {
  static shouldRender(args, { siteSettings, currentUser }) {
    return (
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

  // Asking is a search type here rather than a mode, so the answer belongs on
  // screen exactly while that type is the one selected.
  get shouldShow() {
    return (
      this.creditCheckComplete &&
      this.creditsAvailable &&
      this.args.outletArgs.type === SEARCH_TYPE_ASK_AI
    );
  }

  get hasContent() {
    return this.discobotDiscoveries.showDiscoveryTitle;
  }

  <template>
    {{#if this.shouldShow}}
      {{#if this.hasContent}}
        {{bodyClass "has-discoveries"}}
      {{/if}}
      <div
        class={{dConcatClass
          "ai-search-discoveries__discoveries-wrapper"
          (if this.hasContent "--has-content")
        }}
      >
        <div class="full-page-discoveries">
          <AiSearchDiscoveries
            @searchTerm={{@outletArgs.search}}
            @showHeading={{true}}
            @showSources={{true}}
            @fullPage={{true}}
            {{! the search type runs the discovery when the search is submitted,
                so mounting must not run a second one }}
            @triggerOnInsert={{false}}
          />
        </div>
      </div>
    {{/if}}
  </template>
}
