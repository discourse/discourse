import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import DButton from "discourse/components/d-button";
import { popupAjaxError } from "discourse/lib/ajax-error";
import I18n from "discourse-i18n";
import gte from "truth-helpers/helpers/gte";
import MembersCount from "./members-count";
import MembersSelector from "./members-selector";

export default class NewGroup extends Component {
  @service chat;
  @service router;
  @service siteSettings;

  @tracked newGroupTitle = "";

  placeholder = I18n.t("chat.direct_message_creator.group_name");

  get membersCount() {
    return this.args.members?.length;
  }

  @action
  async createGroup() {
    try {
      const channel = await this.chat.upsertDmChannelForUsernames(
        this.args.members.mapBy("model.username"),
        this.newGroupTitle
      );

      if (!channel) {
        return;
      }

      this.args.close?.();
      this.router.transitionTo("chat.channel", ...channel.routeModels);
    } catch (error) {
      popupAjaxError(error);
    }
  }

  <template>
    <div class="chat-message-creator__new-group-container">
      <div class="chat-message-creator__new-group">
        <div class="chat-message-creator__new-group-header-container">
          <div class="chat-message-creator__new-group-header">
            <Input
              name="channel-name"
              class="chat-message-creator__new-group-header__input"
              placeholder={{this.placeholder}}
              @value={{this.newGroupTitle}}
            />

            <MembersCount
              @count={{this.membersCount}}
              @max={{this.siteSettings.chat_max_direct_message_users}}
            />
          </div>
        </div>

        <MembersSelector
          @members={{@members}}
          @channel={{@channel}}
          @onChange={{@onChangeMembers}}
          @close={{@close}}
          @cancel={{@cancel}}
          @maxReached={{gte
            this.membersCount
            this.siteSettings.chat_max_direct_message_users
          }}
        />

        {{#if @members.length}}
          <div class="chat-message-creator__new-group-footer-container">
            <div class="chat-message-creator__new-group-footer">
              <DButton
                class="btn-primary btn-flat"
                @label="cancel"
                @action={{@cancel}}
              />
              <DButton
                class="btn-primary create-chat-group"
                @label="chat.new_message_modal.create_new_group_chat"
                @action={{this.createGroup}}
              />

            </div>
          </div>
        {{/if}}
      </div>
    </div>
  </template>
}
