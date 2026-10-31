import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import legacyPickOne from "discourse/lib/legacy-pick-one";
import UserChooser from "discourse/select-kit/components/user-chooser";
import DSelectUser from "discourse/ui-kit/select/recipes/users/d-select-user";
import { i18n } from "discourse-i18n";
import BaseField from "./da-base-field.gjs";
import DAFieldDescription from "./da-field-description.gjs";
import DAFieldLabel from "./da-field-label.gjs";

export default class UserField extends BaseField {
  @service siteSettings;

  @action
  onChangeUsername(usernames) {
    this.mutValue(usernames[0]);
  }

  /** The trigger's contexts, offered ahead of the users. */
  @action
  contextItems() {
    const field = this.args.field;
    return field.acceptedContexts.map((context) => ({
      id: context,
      name: i18n(
        `discourse_automation.scriptables.${field.targetName}.fields.${field.name}.${context}_context`
      ),
    }));
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
        <DAFieldLabel @field={{@field}} @label={{@label}} />

        <div class="controls">
          {{! TODO (select-kit-replacement-cleanup) }}
          {{#if this.siteSettings.enable_new_select_controls}}
            <DSelectUser
              @clearable={{true}}
              @disabled={{@field.isDisabled}}
              @onChange={{legacyPickOne this.onChangeUsername}}
              @specialItems={{this.contextItems}}
              @texts={{hash ariaLabel=@label}}
              @value={{@field.metadata.value}}
            />
          {{else}}
            {{! TODO (select-kit-replacement-cleanup) }}
            <UserChooser
              @modifyContent={{fn this.modifyContent @field}}
              @onChange={{this.onChangeUsername}}
              @options={{hash
                maximum=1
                excludeCurrentUser=false
                disabled=@field.isDisabled
              }}
              @value={{@field.metadata.value}}
            />
          {{/if}}

          <DAFieldDescription @description={{@description}} />
        </div>
      </div>
    </section>
  </template>
}
