import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import formatUsername from "discourse/helpers/format-username";
import DButton from "discourse/ui-kit/d-button";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import concatClass from "discourse/ui-kit/helpers/d-concat-class";
import icon from "discourse/ui-kit/helpers/d-icon";

const AssigneeRow = <template>
  <DButton
    class={{concatClass
      "btn-default assign-sheet__assignee-row"
      (if @selected "--selected")
    }}
    {{on "click" (fn @onPress @assignee)}}
  >
    <span class="assign-sheet__assignee-avatar">
      {{#if @assignee.username}}
        {{dAvatar @assignee imageSize="medium"}}
      {{else if @assignee.name}}
        {{icon "users"}}
      {{else}}
        <span class="assign-sheet__no-assignee">
          {{icon "user"}}
        </span>
      {{/if}}
    </span>

    <span class="assign-sheet__assignee-details">
      <span class="assign-sheet__assignee-name">
        {{#if @assignee.username}}
          {{formatUsername @assignee.username}}
        {{else if @assignee.name}}
          {{@assignee.name}}
        {{else}}
          {{yield}}
        {{/if}}
      </span>
    </span>

    {{#if @disclosureIndicatorIcon}}
      {{icon @disclosureIndicatorIcon class="disclosure-indicator-icon"}}
    {{/if}}
  </DButton>
</template>;

export default AssigneeRow;
