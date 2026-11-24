import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { isBlank } from "@ember/utils";
import UserChooser from "discourse/select-kit/components/user-chooser";
import DSelectUser from "discourse/ui-kit/select/recipes/users/d-select-user";
import BaseField from "./da-base-field.gjs";
import DAFieldDescription from "./da-field-description.gjs";
import DAFieldLabel from "./da-field-label.gjs";

export default class UsersField extends BaseField {
  @service siteSettings;

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
        <DAFieldLabel @field={{@field}} @label={{@label}} />

        <div class="controls">
          {{! TODO (select-kit-replacement-cleanup) }}
          {{#if this.siteSettings.enable_new_select_controls}}
            <DSelectUser
              @disabled={{@field.isDisabled}}
              @emails={{true}}
              @multiple={{true}}
              @onChange={{this.onChangeUsers}}
              @texts={{hash ariaLabel=@label}}
              @value={{@field.metadata.value}}
            />
          {{else}}
            {{! TODO (select-kit-replacement-cleanup) }}
            <UserChooser
              @onChange={{this.onChangeUsers}}
              @options={{hash
                excludeCurrentUser=false
                disabled=@field.isDisabled
                allowEmails=true
              }}
              @value={{@field.metadata.value}}
            />
          {{/if}}

          {{#if @field.metadata.allowsAutomation}}
            <span class="help-inline error">{{@field.metadata.error}}</span>
          {{/if}}

          <DAFieldDescription @description={{@description}} />
        </div>
      </div>
    </section>
  </template>
}
