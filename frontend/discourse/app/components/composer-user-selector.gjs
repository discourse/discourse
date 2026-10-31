/* eslint-disable ember/no-classic-components, ember/require-tagless-components */
import Component from "@ember/component";
import { hash } from "@ember/helper";
import { action, computed } from "@ember/object";
import { selectControl } from "discourse/lib/select-control";
import EmailGroupUserChooser from "discourse/select-kit/components/email-group-user-chooser";
import DSelectUser from "discourse/ui-kit/select/recipes/users/d-select-user";
import { i18n } from "discourse-i18n";

export default class ComposerUserSelector extends Component {
  _groups = [];

  @computed("recipients")
  get splitRecipients() {
    if (Array.isArray(this.recipients)) {
      return this.recipients;
    }
    return this.recipients ? this.recipients.split(",").filter(Boolean) : [];
  }

  didInsertElement() {
    super.didInsertElement(...arguments);

    if (this.focusTarget === "usernames") {
      selectControl(this.element)?.focus();
    }
  }

  @action
  updateRecipients(selected, content) {
    // TODO (select-kit-replacement-cleanup): Only `type` remains once select-kit is removed.
    const newGroups = content
      .filter((group) => group.isGroup || group.type === "group")
      .map((item) => item.id);
    this._updateGroups(selected, newGroups);
    this.set("recipients", selected.join(","));
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

  <template>
    {{! TODO (select-kit-replacement-cleanup): Keep the picker switch until rollout completes. }}
    {{#if this.siteSettings.enable_new_select_controls}}
      <DSelectUser
        @emails={{this.currentUser.can_send_private_email_messages}}
        @id="private-message-users"
        @includeGroups="messageable"
        @multiple={{true}}
        @onChange={{this.updateRecipients}}
        @texts={{hash placeholder=(i18n "composer.users_placeholder")}}
        @topicId={{this.topicId}}
        @value={{this.splitRecipients}}
      />
    {{else}}
      {{! TODO (select-kit-replacement-cleanup): Remove the legacy picker after rollout. }}
      <EmailGroupUserChooser
        @id="private-message-users"
        @onChange={{this.updateRecipients}}
        @options={{hash
          topicId=this.topicId
          none="composer.users_placeholder"
          includeMessageableGroups=true
          allowEmails=this.currentUser.can_send_private_email_messages
          autoWrap=true
        }}
        @value={{this.splitRecipients}}
      />
    {{/if}}
  </template>
}
