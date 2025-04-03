import Component from "@ember/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import discourseComputed from "discourse/lib/decorators";
import EmailGroupUserChooser from "select-kit/components/email-group-user-chooser";

export default class ComposerUserSelector extends Component {
  _groups = [];

  didInsertElement() {
    super.didInsertElement(...arguments);

    if (this.focusTarget === "usernames") {
      this.element.querySelector(".select-kit .select-kit-header").focus();
    }
  }

  @discourseComputed("recipients")
  splitRecipients(recipients) {
    if (Array.isArray(recipients)) {
      return recipients;
    }
    return recipients ? recipients.split(",").filter(Boolean) : [];
  }

  _updateGroups(selected, newGroups) {
    const groups = [];
    this._groups.forEach((existing) => {
      if (selected.includes(existing)) {
        groups.addObject(existing);
      }
    });
    newGroups.forEach((newGroup) => {
      if (!groups.includes(newGroup)) {
        groups.addObject(newGroup);
      }
    });
    this.setProperties({
      _groups: groups,
      hasGroups: groups.length > 0,
    });
  }

  @action
  updateRecipients(selected, content) {
    const newGroups = content.filterBy("isGroup").mapBy("id");
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
