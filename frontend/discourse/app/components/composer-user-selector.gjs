/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { hash } from "@ember/helper";
import { action, computed } from "@ember/object";
import EmailGroupUserChooser from "discourse/select-kit/components/email-group-user-chooser";

export default class ComposerUserSelector extends Component {
  _groups = [];

  didInsertElement() {
    super.didInsertElement(...arguments);

    if (this.focusTarget === "usernames") {
      this.element.querySelector(".select-kit .select-kit-header").focus();
    }
  }

  @computed("recipients")
  get splitRecipients() {
    if (Array.isArray(this.recipients)) {
      return this.recipients;
    }
    return this.recipients ? this.recipients.split(",").filter(Boolean) : [];
  }

  _updateGroups(selected, newGroups) {
    const groups = new Set();
    this._groups.forEach((existing) => {
      if (selected.includes(existing)) {
        groups.add(existing);
      }
    });
    newGroups.forEach((newGroup) => {
      groups.add(newGroup);
    });
    this.setProperties({
      _groups: Array.from(groups),
      hasGroups: groups.length > 0,
    });
  }

  @action
  updateRecipients(selected, content) {
    const newGroups = content
      .filter((group) => group.isGroup)
      .map((item) => item.id);
    this._updateGroups(selected, newGroups);
    this.set("recipients", selected.join(","));
  }

  <template>
    <EmailGroupUserChooser
      @id="private-message-users"
      @value={{this.splitRecipients}}
      @onChange={{this.updateRecipients}}
      @options={{hash
        topicId=this.topicId
        none="composer.users_placeholder"
        includeMessageableGroups=true
        allowEmails=this.currentUser.can_send_private_email_messages
        autoWrap=true
      }}
    />
  </template>
}
