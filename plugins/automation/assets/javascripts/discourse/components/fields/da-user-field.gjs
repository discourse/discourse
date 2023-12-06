import { hash } from "@ember/helper";
import { action } from "@ember/object";
import UserChooser from "select-kit/components/user-chooser";
import BaseField from "./da-base-field";
import DAFieldDescription from "./da-field-description";
import DAFieldLabel from "./da-field-label";

export default class UserField extends BaseField {
  <template>
    <section class="field user-field">
      <div class="control-group">
        <DAFieldLabel @label={{@label}} @field={{@field}} />

        <div class="controls">
          <UserChooser
            @value={{@field.metadata.value}}
            @onChange={{this.onChangeUsername}}
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

  @action
  onChangeUsername(usernames) {
    this.mutValue(usernames[0]);
  }
}
