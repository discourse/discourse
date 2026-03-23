import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import DToggleSwitch from "discourse/components/d-toggle-switch";
import { not } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

const StatusToggle = <template>
  <div class="workflows-canvas__status">
    <span
      class="workflows-canvas__status-indicator
        {{if @enabled '--published' '--draft'}}"
    >{{if
        @enabled
        (i18n "discourse_workflows.enabled")
        (i18n "discourse_workflows.disabled")
      }}</span>
    <DToggleSwitch
      @state={{@enabled}}
      {{on "click" (fn @onToggle (not @enabled))}}
    />
  </div>
</template>;

export default StatusToggle;
