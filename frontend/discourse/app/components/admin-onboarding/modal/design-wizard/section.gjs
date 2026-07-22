import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import dIcon from "discourse/ui-kit/helpers/d-icon";

const DesignWizardSection = <template>
  <section
    class="design-wizard-modal__section {{if @open '--open'}}"
    data-section-id={{@id}}
  >
    <button
      type="button"
      class="design-wizard-modal__section-toggle"
      aria-expanded={{if @open "true" "false"}}
      {{on "click" (fn @onToggle @id)}}
    >
      <span class="design-wizard-modal__section-title">{{@title}}</span>
      <span class="design-wizard-modal__section-summary">
        {{#unless @open}}{{@summary}}{{/unless}}
        {{dIcon (if @open "chevron-up" "chevron-down")}}
      </span>
    </button>
    {{#if @open}}
      <div class="design-wizard-modal__section-body">
        {{yield}}
      </div>
    {{/if}}
  </section>
</template>;

export default DesignWizardSection;
