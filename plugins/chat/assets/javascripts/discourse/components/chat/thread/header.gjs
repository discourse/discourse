import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { inject as service } from "@ember/service";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import replaceEmoji from "discourse/helpers/replace-emoji";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { NotificationLevels } from "discourse/lib/notification-levels";
import icon from "discourse-common/helpers/d-icon";
import I18n from "discourse-i18n";
import ChatModalThreadSettings from "discourse/plugins/chat/discourse/components/chat/modal/thread-settings";
import ChatThreadHeaderUnreadIndicator from "discourse/plugins/chat/discourse/components/chat/thread/header-unread-indicator";
import UserChatThreadMembership from "discourse/plugins/chat/discourse/models/user-chat-thread-membership";
import ThreadNotificationsButton from "discourse/plugins/chat/select-kit/addons/components/thread-notifications-button";

export default class ChatThreadHeader extends Component {
  @service currentUser;
  @service chatApi;
  @service router;
  @service chatStateManager;
  @service chatHistory;
  @service site;
  @service modal;

  @tracked persistedNotificationLevel = true;

  closeThreadTitle = I18n.t("chat.thread.close");

  get backLink() {
    const prevPage = this.chatHistory.previousRoute?.name;
    let route, title;

    if (prevPage === "chat.channel.threads") {
      route = "chat.channel.threads";
      title = I18n.t("chat.return_to_threads_list");
    } else if (prevPage === "chat.channel.index" && !this.site.mobileView) {
      route = "chat.channel.threads";
      title = I18n.t("chat.return_to_threads_list");
    } else {
      route = "chat.channel.index";
      title = I18n.t("chat.return_to_channel");
    }

    return {
      route,
      models: this.args.channel.routeModels,
      title,
    };
  }

  get canChangeThreadSettings() {
    if (!this.args.thread) {
      return false;
    }

    return (
      this.currentUser.staff ||
      this.currentUser.id === this.args.thread.originalMessage.user.id
    );
  }

  get threadNotificationLevel() {
    return this.membership?.notificationLevel || NotificationLevels.REGULAR;
  }

  get membership() {
    return this.args.thread.currentUserMembership;
  }

  get headerTitle() {
    return this.args.thread?.title ?? I18n.t("chat.thread.label");
  }

  @action
  openThreadSettings() {
    this.modal.show(ChatModalThreadSettings, { model: this.args.thread });
  }

  @action
  updateThreadNotificationLevel(newNotificationLevel) {
    this.persistedNotificationLevel = false;

    let currentNotificationLevel;

    if (this.membership) {
      currentNotificationLevel = this.membership.notificationLevel;
      this.membership.notificationLevel = newNotificationLevel;
    } else {
      this.args.thread.currentUserMembership = UserChatThreadMembership.create({
        notification_level: newNotificationLevel,
        last_read_message_id: null,
      });
    }

    return this.chatApi
      .updateCurrentUserThreadNotificationsSettings(
        this.args.thread.channel.id,
        this.args.thread.id,
        { notificationLevel: newNotificationLevel }
      )
      .then((response) => {
        this.membership.last_read_message_id =
          response.membership.last_read_message_id;

        this.persistedNotificationLevel = true;
      })
      .catch((err) => {
        this.membership.notificationLevel = currentNotificationLevel;
        popupAjaxError(err);
      });
  }

  <template>
    <div class="chat-thread-header">
      <div class="chat-thread-header__left-buttons">
        {{#if @thread}}
          <LinkTo
            class="chat-thread__back-to-previous-route btn-flat btn btn-icon no-text"
            @route={{this.backLink.route}}
            @models={{this.backLink.models}}
            title={{this.backLink.title}}
          >
            <ChatThreadHeaderUnreadIndicator @channel={{@thread.channel}} />
            {{icon "chevron-left"}}
          </LinkTo>
        {{/if}}
      </div>

      <span class="chat-thread-header__label overflow-ellipsis">
        {{replaceEmoji this.headerTitle}}
      </span>

      <div
        class={{concatClass
          "chat-thread-header__buttons"
          (if this.persistedNotificationLevel "-persisted")
        }}
      >
        <ThreadNotificationsButton
          @value={{this.threadNotificationLevel}}
          @onChange={{this.updateThreadNotificationLevel}}
        />
        {{#if this.canChangeThreadSettings}}
          <DButton
            @action={{this.openThreadSettings}}
            @icon="cog"
            @title="chat.thread.settings"
            class="btn-flat chat-thread-header__settings"
          />
        {{/if}}
        {{#unless this.site.mobileView}}
          <LinkTo
            class="chat-thread__close btn-flat btn btn-icon no-text"
            @route="chat.channel"
            @models={{@thread.channel.routeModels}}
            title={{this.closeThreadTitle}}
          >
            {{icon "times"}}
          </LinkTo>
        {{/unless}}
      </div>
    </div>
  </template>
}
