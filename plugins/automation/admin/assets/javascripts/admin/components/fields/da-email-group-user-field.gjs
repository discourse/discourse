import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import EmailGroupUserChooser from "discourse/select-kit/components/email-group-user-chooser";
import DSelectUser from "discourse/ui-kit/select/recipes/users/d-select-user";
import BaseField from "./da-base-field.gjs";
import DAFieldDescription from "./da-field-description.gjs";
import DAFieldLabel from "./da-field-label.gjs";

export default class EmailGroupUserField extends BaseField {
  @service siteSettings;

  @tracked recipients;
  @tracked groups = [];

  <template>
    <section class="field email-group-user-field">
      <div class="control-group">
        <DAFieldLabel @field={{@field}} @label={{@label}} />

        <div class="controls">
          {{! TODO (select-kit-replacement-cleanup) }}
          {{#if this.siteSettings.enable_new_select_controls}}
            <DSelectUser
              @disabled={{@field.isDisabled}}
              @emails={{true}}
              @includeGroups="visible"
              @multiple={{true}}
              @onChange={{this.mutValue}}
              @texts={{hash ariaLabel=@label}}
              @value={{@field.metadata.value}}
            />
          {{else}}
            {{! TODO (select-kit-replacement-cleanup) }}
            <EmailGroupUserChooser
              @onChange={{this.mutValue}}
              @options={{hash
                includeGroups=true
                includeMessageableGroups=true
                allowEmails=true
                autoWrap=true
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

  @action
  updateRecipients(selected, content) {
    const newGroups = content
      .filter((item) => item.isGroup)
      .map((item) => item.id);
    this._updateGroups(selected, newGroups);
    this.recipients = selected.join(",");
  }

  _updateGroups(selected, newGroups) {
    const groups = new Set();

    this.groups.forEach((existing) => {
      if (selected.includes(existing)) {
        groups.add(existing);
      }
    });

    newGroups.forEach((newGroup) => groups.add(newGroup));

    this.groups = Array.from(groups);
  }
}
