import Component from "@glimmer/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import DButton from "discourse/components/d-button";
import { popupAjaxError } from "discourse/lib/ajax-error";
import I18n from "discourse-i18n";
import gte from "truth-helpers/helpers/gte";
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
    return (
      this.args.members?.length + (this.args.channel?.membershipsCount ?? 0)
    );
  }

  @action
  async saveGroupMembers() {
    try {
      this.loadingSlider.transitionStarted();

      await this.chatApi.addMembersToChannel(
        this.args.channel.id,
        this.args.members.mapBy("model.username")
      );

      this.toasts.success({ data: { message: I18n.t("saved") } });
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
        <MembersCount
          @count={{this.membersCount}}
          @max={{this.siteSettings.chat_max_direct_message_users}}
        />

        <MembersSelector
          @channel={{@channel}}
          @members={{@members}}
          @onChange={{@onChangeMembers}}
          @close={{@close}}
          @cancel={{@cancel}}
          @maxReached={{gte
            this.membersCount
            this.siteSettings.chat_max_direct_message_users
          }}
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
