import Component from "@glimmer/component";
import { service } from "@ember/service";
import noop from "discourse/helpers/noop";
import replaceEmoji from "discourse/helpers/replace-emoji";
import icon from "discourse-common/helpers/d-icon";
import { i18n } from "discourse-i18n";
import and from "truth-helpers/helpers/and";
import ThreadSettingsModal from "discourse/plugins/chat/discourse/components/chat/modal/thread-settings";
import Navbar from "discourse/plugins/chat/discourse/components/chat/navbar";
import ChatThreadHeaderUnreadIndicator from "discourse/plugins/chat/discourse/components/chat/thread/header-unread-indicator";

export default class ChatThreadHeader extends Component {
  @service currentUser;
  @service chatHistory;
  @service modal;
  @service site;

  get backLink() {
    const prevPage = this.chatHistory.previousRoute?.name;
    let route, title, models;

    if (prevPage === "chat.channel.threads") {
      route = "chat.channel.threads";
      title = i18n("chat.return_to_threads_list");
      models = this.channel?.routeModels;
    } else if (prevPage === "chat.channel.index" && this.site.desktopView) {
      route = "chat.channel.threads";
      title = i18n("chat.return_to_threads_list");
      models = this.channel?.routeModels;
    } else if (prevPage === "chat.threads") {
      route = "chat.threads";
      title = i18n("chat.my_threads.title");
      models = [];
    } else if (!this.currentUser.isInDoNotDisturb() && this.unreadCount > 0) {
      route = "chat.channel.threads";
      title = i18n("chat.return_to_threads_list");
      models = this.channel?.routeModels;
    } else {
      route = "chat.channel.index";
      title = i18n("chat.return_to_channel");
      models = this.channel?.routeModels;
    }

    return { route, models, title };
  }

  get channel() {
    return this.args.thread?.channel;
  }

  get headerTitle() {
    return this.args.thread?.title ?? i18n("chat.thread.label");
  }

  get unreadCount() {
    return this.channel?.threadsManager?.unreadThreadCount;
  }

  get showThreadUnreadIndicator() {
    return (
      this.backLink.route === "chat.channel.threads" && this.unreadCount > 0
    );
  }

  get openThreadTitleModal() {
    if (
      this.currentUser.admin ||
      this.currentUser.id === this.args.thread?.originalMessage?.user?.id
    ) {
      return () =>
        this.modal.show(ThreadSettingsModal, { model: this.args.thread });
    } else {
      return noop;
    }
  }

  <template>
    <Navbar @showFullTitle={{@showFullTitle}} as |navbar|>
      {{#if (and this.channel.threadingEnabled @thread)}}
        <navbar.BackButton
          @route={{this.backLink.route}}
          @routeModels={{this.backLink.models}}
          @title={{this.backLink.title}}
        >
          {{#if this.showThreadUnreadIndicator}}
            <ChatThreadHeaderUnreadIndicator @channel={{this.channel}} />
          {{/if}}
          {{icon "chevron-left"}}
        </navbar.BackButton>
      {{/if}}

      <navbar.Title
        @title={{replaceEmoji this.headerTitle}}
        @openThreadTitleModal={{this.openThreadTitleModal}}
      />
      <navbar.Actions as |action|>
        <action.ThreadTrackingDropdown @thread={{@thread}} />
        <action.ThreadSettingsButton @thread={{@thread}} />
        <action.CloseThreadButton @thread={{@thread}} />
      </navbar.Actions>
    </Navbar>
  </template>
}
