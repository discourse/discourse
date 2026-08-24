import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action, set } from "@ember/object";
import { service } from "@ember/service";
import ComboBox from "discourse/select-kit/components/combo-box";
import { i18n } from "discourse-i18n";

export default class AiAutomationFilter extends Component {
  static shouldRender(args, { currentUser }) {
    return args.additionalFilters && currentUser?.ai_triage_automations?.length;
  }

  @service currentUser;

  @action
  updateAutomation(automationId) {
    set(
      this.args.outletArgs.additionalFilters,
      "ai_triage_automation_id",
      automationId
    );
  }

  <template>
    <div class="reviewable-filter ai-automation-filter" ...attributes>
      <label class="filter-label">
        {{i18n "discourse_ai.review_filters.ai_automation"}}
      </label>
      <ComboBox
        @value={{@outletArgs.additionalFilters.ai_triage_automation_id}}
        @content={{this.currentUser.ai_triage_automations}}
        @onChange={{this.updateAutomation}}
        @options={{hash none="discourse_ai.review_filters.all_ai_automations"}}
      />
    </div>
  </template>
}
