import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import EmailGroupUserChooser from "discourse/select-kit/components/email-group-user-chooser";
import BaseField from "./da-base-field";
import DAFieldDescription from "./da-field-description";
import DAFieldLabel from "./da-field-label";

export default class EmailGroupUserField extends BaseField {
  @tracked recipients;
  @tracked groups = [];

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
