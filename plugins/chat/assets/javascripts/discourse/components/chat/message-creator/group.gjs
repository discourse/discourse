import Component from "@glimmer/component";
import { service } from "@ember/service";
import icon from "discourse-common/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class ChatableGroup extends Component {
  @service currentUser;
  @service siteSettings;

  group_with_too_many_members = i18n(
    "chat.new_message_modal.group_with_too_many_members",
    { membersCount: this.args.item.model.chat_enabled_user_count }
  );

  get isDisabled() {
    if (!this.args.membersCount) {
      return !this.args.item.enabled;
    }

    return (
      this.args.membersCount + this.args.item.model.chat_enabled_user_count >
      this.siteSettings.chat_max_direct_message_users
    );
  }

  <template>
    <div
      class="chat-message-creator__chatable -group"
      data-disabled={{this.isDisabled}}
    >
      <div class="chat-message-creator__group-icon">
        {{icon "user-group"}}
      </div>
      <div class="chat-message-creator__group-name">
        {{@item.model.name}}
      </div>

      {{#if this.isDisabled}}
        <span class="chat-message-creator__disabled-warning">
          {{this.group_with_too_many_members}}
        </span>
      {{/if}}
    </div>
  </template>
}
