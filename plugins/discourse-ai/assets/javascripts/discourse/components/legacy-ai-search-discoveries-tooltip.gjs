import Component from "@glimmer/component";
import { service } from "@ember/service";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class LegacyAiSearchDiscoveriesTooltip extends Component {
  @service("legacy-discobot-discoveries") legacyDiscoveries;

  <template>
    <span class="ai-search-discoveries-tooltip">
      <DTooltip @interactive={{true}} @placement="top-end">
        <:trigger>
          {{dIcon "circle-info"}}
        </:trigger>
        <:content>
          <div class="ai-search-discoveries-tooltip__content">
            <div class="ai-search-discoveries-tooltip__header">
              {{i18n "discourse_ai.discobot_discoveries.legacy.tooltip.header"}}
            </div>

            <div class="ai-search-discoveries-tooltip__description">
              {{#if this.legacyDiscoveries.modelUsed}}
                {{i18n
                  "discourse_ai.discobot_discoveries.legacy.tooltip.content"
                  model=this.legacyDiscoveries.modelUsed
                }}
              {{/if}}
            </div>

            <div class="ai-search-discoveries-tooltip__actions">
              <DButton
                class="btn-transparent --primary"
                @href="https://meta.discourse.org/t/conversational-ai-search-coming-to-discourse-ai/355939"
                @label="discourse_ai.discobot_discoveries.legacy.tooltip.actions.info"
              />
              <DButton
                class="btn-transparent btn-danger"
                @action={{this.legacyDiscoveries.disableDiscoveries}}
                @label="discourse_ai.discobot_discoveries.legacy.tooltip.actions.disable"
              />
            </div>
          </div>
        </:content>
      </DTooltip>
    </span>
  </template>
}
