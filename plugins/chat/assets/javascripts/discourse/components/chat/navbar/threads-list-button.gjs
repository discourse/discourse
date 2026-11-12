import Component from "@glimmer/component";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import ThreadHeaderUnreadIndicator from "discourse/plugins/chat/discourse/components/chat/thread/header-unread-indicator";

export default class ChatNavbarThreadsListButton extends Component {
  @service router;
  @service chatStateManager;

  threadsListLabel = i18n("chat.threads.list");

  get showThreadsListButton() {
    return (
      this.args.channel?.threadingEnabled &&
      !this.chatStateManager.isDrawerCollapsed &&
      this.router.currentRoute.name !== "chat.channel.threads" &&
      this.router.currentRoute.name !== "chat.channel.thread" &&
      this.router.currentRoute.name !== "chat.channel.thread.index"
    );
  }

  <template>
    {{#if this.showThreadsListButton}}
      <LinkTo
        class={{dConcatClass
          "c-navbar__threads-list-button"
          "btn"
          "no-text"
          "btn-transparent"
          (if @channel.threadsManager.unreadThreadCount "has-unreads")
        }}
        title={{this.threadsListLabel}}
        @models={{@channel.routeModels}}
        @route="chat.channel.threads"
      >
        {{dIcon "discourse-threads"}}
        <ThreadHeaderUnreadIndicator @channel={{@channel}} />
      </LinkTo>
    {{/if}}
  </template>
}
