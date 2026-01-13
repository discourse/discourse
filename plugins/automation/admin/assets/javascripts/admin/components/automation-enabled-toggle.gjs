import { on } from "@ember/modifier";
import DToggleSwitch from "discourse/components/d-toggle-switch";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import { i18n } from "discourse-i18n";

const AutomationEnabledToggle = <template>
  {{#if @canBeEnabled}}
    <DToggleSwitch @state={{@automation.enabled}} {{on "click" @onToggle}} />
  {{else}}
    <DTooltip @identifier="automation-enabled-toggle">
      <:trigger>
        <DToggleSwitch disabled={{true}} @state={{@automation.enabled}} />
      </:trigger>
      <:content>
        {{i18n "discourse_automation.models.automation.enable_toggle_disabled"}}
      </:content>
    </DTooltip>
  {{/if}}
</template>;

export default AutomationEnabledToggle;
