import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { isBlank } from "@ember/utils";
import UserChooser from "select-kit/components/user-chooser";
import BaseField from "./da-base-field";
import DAFieldDescription from "./da-field-description";
import DAFieldLabel from "./da-field-label";

export default class UsersField extends BaseField {
  @action
  onChangeUsers(users) {
    if (isBlank(users)) {
      users = undefined;
    }

    this.mutValue(users);
  }

  <template>
    <section class="field users-field">
      <div class="control-group">
        <DAFieldLabel @label={{@label}} @field={{@field}} />

        <div class="controls">
          <UserChooser
            @value={{@field.metadata.value}}
            @onChange={{this.onChangeUsers}}
            @options={{hash
              excludeCurrentUser=false
              disabled=@field.isDisabled
              allowEmails=true
            }}
          />

          {{#if @field.metadata.allowsAutomation}}
            <span class="help-inline error">{{@field.metadata.error}}</span>
          {{/if}}

          <DAFieldDescription @description={{@description}} />
        </div>
      </div>
    </section>
  </template>
}
