import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import legacyPickOne from "discourse/lib/legacy-pick-one";
import UserChooser from "discourse/select-kit/components/user-chooser";
import DSelectUser from "discourse/ui-kit/select/recipes/users/d-select-user";
import ExpressionWrapper from "./expression-wrapper.gjs";

function usernamesFromValue(value) {
  if (Array.isArray(value)) {
    return value;
  }

  if (typeof value === "string" && value.length > 0) {
    return [value];
  }

  return [];
}

export default class UserControl extends Component {
  @service siteSettings;

  get multiple() {
    return Boolean(this.args.schema?.ui?.multiple);
  }

  get value() {
    const usernames = usernamesFromValue(this.args.field.value);
    return this.multiple ? usernames : usernames[0] || null;
  }

  get maximum() {
    return this.multiple ? null : 1;
  }

  @action
  handleChange(usernames) {
    this.args.field.set(this.multiple ? usernames || [] : usernames[0] || "");
  }

  <template>
    <ExpressionWrapper
      @dynamicValueHint={{@dynamicValueHint}}
      @field={{@field}}
      @placeholder={{@placeholder}}
      @schema={{@schema}}
      @session={{@session}}
      @supportsExpression={{@supportsExpression}}
    >
      {{! TODO (select-kit-replacement-cleanup) }}
      {{#if this.siteSettings.enable_new_select_controls}}
        <DSelectUser
          @clearable={{not this.multiple}}
          @describedBy={{@field.describedBy}}
          @disabled={{@field.disabled}}
          @id={{@field.id}}
          @invalid={{if @field.error true false}}
          @multiple={{this.multiple}}
          @onChange={{if
            this.multiple
            this.handleChange
            (legacyPickOne this.handleChange)
          }}
          @texts={{hash ariaLabel=@field.title}}
          @value={{this.value}}
        />
      {{else}}
        {{! TODO (select-kit-replacement-cleanup) }}
        <UserChooser
          @onChange={{this.handleChange}}
          @options={{hash maximum=this.maximum excludeCurrentUser=false}}
          @value={{this.value}}
        />
      {{/if}}
    </ExpressionWrapper>
  </template>
}
