import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { gte } from "truth-helpers";
import DButton from "discourse/components/d-button";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import MembersCount from "./members-count";
import MembersSelector from "./members-selector";

export default class AddMembers extends Component {
  @service chat;
  @service chatApi;
  @service router;
  @service toasts;
  @service siteSettings;
  @service loadingSlider;

  get membersCount() {
    const userCount = this.args.members?.reduce((acc, member) => {
      if (member.type === "group") {
        return acc + member.model.chat_enabled_user_count;
      } else {
        return acc + 1;
      }
    }, 0);
    return userCount + (this.args.channel?.membershipsCount ?? 0);
  }

  get maxMembers() {
    return this.siteSettings.chat_max_direct_message_users;
  }

  @action
  async saveGroupMembers() {
    try {
      this.loadingSlider.transitionStarted();

      const usernames = this.args.members
        .filter((member) => member.type === "user")
        .mapBy("model.username");

      const groups = this.args.members
        .filter((member) => member.type === "group")
        .mapBy("model.name");

      await this.chatApi.addMembersToChannel(this.args.channel.id, {
        usernames,
        groups,
      });

      this.toasts.success({ data: { message: i18n("saved") } });
      this.router.transitionTo(
        "chat.channel",
        ...this.args.channel.routeModels
      );
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.loadingSlider.transitionEnded();
    }
  }

  <template>
    <div class="chat-message-creator__add-members-container">
      <div class="chat-message-creator__add-members">
        <MembersCount @count={{this.membersCount}} @max={{this.maxMembers}} />

        <MembersSelector
          @channel={{@channel}}
          @members={{@members}}
          @onChange={{@onChangeMembers}}
          @close={{@close}}
          @cancel={{@cancel}}
          @membersCount={{this.membersCount}}
          @maxReached={{gte this.membersCount this.maxMembers}}
        />

        {{#if @members.length}}
          <div class="chat-message-creator__add-members-footer-container">
            <div class="chat-message-creator__add-members-footer">
              <DButton class="btn-flat" @label="cancel" @action={{@cancel}} />

              <DButton
                class="btn-primary add-to-channel"
                @label="chat.direct_message_creator.add_to_channel"
                @action={{this.saveGroupMembers}}
              />
            </div>
          </div>
        {{/if}}
      </div>
    </div>
  </template>
}
