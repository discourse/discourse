import BaseField from "./da-base-field";
import { action } from "@ember/object";
import EmailGroupUserChooser from "select-kit/components/email-group-user-chooser";
import DAFieldLabel from "./da-field-label";
import DAFieldDescription from "./da-field-description";
import { hash } from "@ember/helper";
import { tracked } from "@glimmer/tracking";

export default class EmailGroupUserField extends BaseField {
  <template>
    <section class="field email-group-user-field">
      <div class="control-group">
        <DAFieldLabel @label={{@label}} @field={{@field}} />

        <div class="controls">
          <EmailGroupUserChooser
            @value={{@field.metadata.value}}
            @onChange={{this.mutValue}}
            @options={{hash
              includeGroups=true
              includeMessageableGroups=true
              allowEmails=true
              autoWrap=true
              disabled=@field.isDisabled
            }}
          />

          <DAFieldDescription @description={{@description}} />
        </div>
      </div>
    </section>
  </template>

  @tracked recipients;
  @tracked groups = [];

  @action
  updateRecipients(selected, content) {
    const newGroups = content.filterBy("isGroup").mapBy("id");
    this._updateGroups(selected, newGroups);
    this.recipients = selected.join(",");
  }

  _updateGroups(selected, newGroups) {
    const groups = [];

    this.groups.forEach((existing) => {
      if (selected.includes(existing)) {
        groups.addObject(existing);
      }
    });

    newGroups.forEach((newGroup) => {
      if (!groups.includes(newGroup)) {
        groups.addObject(newGroup);
      }
    });

    this.groups = groups;
  }
}
