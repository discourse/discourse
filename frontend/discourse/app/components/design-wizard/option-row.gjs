import { on } from "@ember/modifier";

// A selectable row, rendered like the notification tracking menu's options.
const DesignWizardOptionRow = <template>
  <button
    type="button"
    class="design-wizard__option-row {{if @selected '--selected'}}"
    aria-pressed={{if @selected "true" "false"}}
    ...attributes
    {{on "click" @onSelect}}
  >
    <span class="design-wizard__option-row-texts">
      <span class="design-wizard__option-row-label">{{@label}}</span>
      {{#if @description}}
        <span class="design-wizard__option-row-description">
          {{@description}}
        </span>
      {{/if}}
    </span>
  </button>
</template>;

export default DesignWizardOptionRow;
