import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { i18n } from "discourse-i18n";
import UserChooser from "select-kit/components/user-chooser";
import BaseField from "./da-base-field";
import DAFieldDescription from "./da-field-description";
import DAFieldLabel from "./da-field-label";

export default class UserField extends BaseField {
  @action
  onChangeUsername(usernames) {
    this.mutValue(usernames[0]);
  }

  @action
  modifyContent(field, content) {
    content = field.acceptedContexts
      .map((context) => {
        return {
          name: i18n(
            `discourse_automation.scriptables.${field.targetName}.fields.${field.name}.${context}_context`
          ),
          username: context,
        };
      })
      .concat(content);

    return content;
  }

  <template>
    <section class="field user-field">
      <div class="control-group">
        <DAFieldLabel @label={{@label}} @field={{@field}} />

        <div class="controls">
          <UserChooser
            @value={{@field.metadata.value}}
            @onChange={{this.onChangeUsername}}
            @modifyContent={{fn this.modifyContent @field}}
            @options={{hash
              maximum=1
              excludeCurrentUser=false
              disabled=@field.isDisabled
            }}
          />

          <DAFieldDescription @description={{@description}} />
        </div>
      </div>
    </section>
  </template>
}
