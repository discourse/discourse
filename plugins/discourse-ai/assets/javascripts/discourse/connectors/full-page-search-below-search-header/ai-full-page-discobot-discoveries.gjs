import Component from "@glimmer/component";
import { service } from "@ember/service";
import bodyClass from "discourse/helpers/body-class";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";
import AiSearchDiscoveries from "../../components/ai-search-discoveries";
import AiSearchDiscoveriesTooltip from "../../components/ai-search-discoveries-tooltip";

export default class AiFullPageDiscobotDiscoveries extends Component {
  static shouldRender(_args, { siteSettings, currentUser }) {
    return (
      siteSettings.ai_bot_discover_persona &&
      currentUser?.can_use_ai_bot_discover_persona &&
      currentUser?.user_option?.ai_search_discoveries
    );
  }

  @service capabilities;
  @service discobotDiscoveries;
  @service site;

  get previewLength() {
    if (!this.capabilities.viewport.md) {
      return 50;
    } else {
      return 10000;
    }
  }

  <template>
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
  </template>
}
