import { trustHTML } from "@ember/template";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import AiCreditBar from "discourse/plugins/discourse-ai/discourse/components/ai-credit-bar";

function formatResetDate(dateString) {
  return new Date(dateString).toLocaleString(undefined, {
    month: "long",
    day: "numeric",
    hour: "numeric",
    minute: "2-digit",
    timeZone: "UTC",
  });
}

/**
 * Credit bar plus a warning once the soft or hard daily limit is reached.
 *
 * @component AiCreditAllocationStatus
 * @param {Object} allocation - serialized credit allocation
 */
const AiCreditAllocationStatus = <template>
  <div class="ai-credit-allocation-status">
    <AiCreditBar @allocation={{@allocation}} />
    {{#if @allocation.hard_limit_reached}}
      <div class="alert alert-danger ai-credit-warning">
        {{dIcon "circle-info"}}
        {{trustHTML
          (i18n
            "discourse_ai.llms.credit_allocation.hard_limit_warning"
            reset_date=(formatResetDate @allocation.next_reset_at)
          )
        }}
      </div>
    {{else if @allocation.soft_limit_reached}}
      <div class="alert alert-warning ai-credit-warning">
        {{dIcon "circle-info"}}
        {{trustHTML
          (i18n
            "discourse_ai.llms.credit_allocation.soft_limit_warning"
            percentage=@allocation.percentage_remaining
          )
        }}
      </div>
    {{/if}}
  </div>
</template>;

export default AiCreditAllocationStatus;
