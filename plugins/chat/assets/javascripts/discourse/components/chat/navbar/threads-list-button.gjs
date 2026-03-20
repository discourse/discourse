import Component from "@glimmer/component";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import ThreadHeaderUnreadIndicator from "discourse/plugins/chat/discourse/components/chat/thread/header-unread-indicator";

export default class ChatNavbarThreadsListButton extends Component {
  @service router;

  threadsListLabel = i18n("chat.threads.list");

  get showThreadsListButton() {
    return (
      this.args.channel?.threadingEnabled &&
      this.router.currentRoute.name !== "chat.channel.threads" &&
      this.router.currentRoute.name !== "chat.channel.thread" &&
      this.router.currentRoute.name !== "chat.channel.thread.index"
    );
  }

  <template>
    {{#if this.showThreadsListButton}}
      <LinkTo
        @route="chat.channel.threads"
        @models={{@channel.routeModels}}
        title={{this.threadsListLabel}}
        class={{dConcatClass
          "c-navbar__threads-list-button"
          "btn"
          "no-text"
          "btn-transparent"
          (if @channel.threadsManager.unreadThreadCount "has-unreads")
        }}
      >
        {{dIcon "discourse-threads"}}
        <ThreadHeaderUnreadIndicator @channel={{@channel}} />
      </LinkTo>
    {{/if}}
  </template>
}
