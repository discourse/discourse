import Component from "@glimmer/component";
import { service } from "discourse/lib/service";
import { bind } from "discourse/lib/decorators";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import MessageBusService from "discourse/services/message-bus";

export default class UnreadIndicator extends Component {
  @service(() => MessageBusService) messageBus;

  constructor() {
    super(...arguments);
    this.messageBus.subscribe(this.unreadIndicatorChannel, this.onMessage);
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.messageBus.unsubscribe(this.unreadIndicatorChannel, this.onMessage);
  }

  get unreadIndicatorChannel() {
    return `/private-messages/unread-indicator/${this.args.topic.id}`;
  }

  @bind
  onMessage(data) {
    this.args.topic.set("unread_by_group_member", data.show_indicator);
  }

  <template>
    {{~#if @topic.unread_by_group_member~}}
      &nbsp;<span
        class="badge badge-notification unread-indicator"
        title={{i18n "topic.unread_indicator"}}
      >
        {{~dIcon "asterisk" label=(i18n "topic.unread_indicator")~}}
      </span>
    {{~/if~}}
  </template>
}
