import Component from "@glimmer/component";
import { service } from "@ember/service";
import bodyClass from "discourse/helpers/body-class";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import AiSearchDiscoveries from "../../components/ai-search-discoveries";
import { SEARCH_TYPE_ASK_AI } from "../../lib/full-page-search-types";

export default class AiFullPageDiscobotDiscoveries extends Component {
  static shouldRender(args, { siteSettings, currentUser }) {
    return (
      siteSettings.ai_ask_ai_enabled &&
      siteSettings.ai_ask_ai_agent &&
      currentUser?.can_use_ask_ai
    );
  }

  @service discobotDiscoveries;

  // Asking is a search type here rather than a mode, so the answer belongs on
  // screen exactly while that type is the one selected.
  get shouldShow() {
    return this.args.outletArgs.type === SEARCH_TYPE_ASK_AI;
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
