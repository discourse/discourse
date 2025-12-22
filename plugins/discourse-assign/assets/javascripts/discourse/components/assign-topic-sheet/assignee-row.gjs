import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import DButton from "discourse/components/d-button";
import avatar from "discourse/helpers/avatar";
import icon from "discourse/helpers/d-icon";
import formatUsername from "discourse/helpers/format-username";

export default class AssigneeRow extends Component {
  <template>
    <DButton
      class="btn-default assign-sheet__assignee-row"
      {{on "click" (fn @onPress @assignee)}}
    >
      <span class="assign-sheet__assignee-avatar">
        {{#if @assignee.username}}
          {{avatar @assignee imageSize="medium"}}
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
  </template>
}
