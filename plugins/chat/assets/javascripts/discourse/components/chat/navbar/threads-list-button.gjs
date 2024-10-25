import Component from "@glimmer/component";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse-common/helpers/d-icon";
import I18n from "discourse-i18n";
import ThreadHeaderUnreadIndicator from "discourse/plugins/chat/discourse/components/chat/thread/header-unread-indicator";

export default class ChatNavbarThreadsListButton extends Component {
  @service router;

  threadsListLabel = I18n.t("chat.threads.list");

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
        class={{concatClass
          "c-navbar__threads-list-button"
          "btn"
          "no-text"
          "btn-transparent"
          (if @channel.threadsManager.unreadThreadCount "has-unreads")
        }}
      >
        {{icon "discourse-threads"}}
        <ThreadHeaderUnreadIndicator @channel={{@channel}} />
      </LinkTo>
    {{/if}}
  </template>
}
