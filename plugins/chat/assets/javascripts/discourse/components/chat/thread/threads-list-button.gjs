import Component from "@glimmer/component";
import { LinkTo } from "@ember/routing";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse-common/helpers/d-icon";
import I18n from "I18n";
import ThreadHeaderUnreadIndicator from "discourse/plugins/chat/discourse/components/chat/thread/header-unread-indicator";

export default class ThreadsListButton extends Component {
  threadsListLabel = I18n.t("chat.threads.list");

  <template>
    <LinkTo
      @route="chat.channel.threads"
      @models={{@channel.routeModels}}
      title={{this.threadsListLabel}}
      class={{concatClass
        "chat-threads-list-button"
        "btn"
        "btn-flat"
        (if @channel.threadsManager.unreadThreadCount "has-unreads")
      }}
    >
      {{icon "discourse-threads"}}

      <ThreadHeaderUnreadIndicator @channel={{@channel}} />
    </LinkTo>
  </template>
}
