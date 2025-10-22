import Component from "@glimmer/component";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";
import DTooltip from "float-kit/components/d-tooltip";

export default class AiSearchDiscoveriesTooltip extends Component {
  @service discobotDiscoveries;

  <template>
    <span class="ai-search-discoveries-tooltip">
      <DTooltip @placement="top-end" @interactive={{true}}>
        <:trigger>
          {{icon "circle-info"}}
        </:trigger>
        <:content>
          <div class="ai-search-discoveries-tooltip__content">
            <div class="ai-search-discoveries-tooltip__header">
              {{i18n "discourse_ai.discobot_discoveries.tooltip.header"}}
            </div>

            <div class="ai-search-discoveries-tooltip__description">
              {{#if this.discobotDiscoveries.modelUsed}}
                {{i18n
                  "discourse_ai.discobot_discoveries.tooltip.content"
                  model=this.discobotDiscoveries.modelUsed
                }}
              {{/if}}
            </div>

            <div class="ai-search-discoveries-tooltip__actions">
              <DButton
                class="btn-transparent btn-primary"
                @label="discourse_ai.discobot_discoveries.tooltip.actions.info"
                @href="https://meta.discourse.org/t/conversational-ai-search-coming-to-discourse-ai/355939"
              />
              <DButton
                class="btn-transparent btn-danger"
                @label="discourse_ai.discobot_discoveries.tooltip.actions.disable"
                @action={{this.discobotDiscoveries.disableDiscoveries}}
              />
            </div>
          </div>
        </:content>
      </DTooltip>
    </span>
  </template>
}
