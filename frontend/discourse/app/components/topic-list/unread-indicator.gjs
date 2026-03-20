import Component from "@glimmer/component";
import { service } from "@ember/service";
import { bind } from "discourse/lib/decorators";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class UnreadIndicator extends Component {
  @service messageBus;

  constructor() {
    super(...arguments);
    this.messageBus.subscribe(this.unreadIndicatorChannel, this.onMessage);
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.messageBus.unsubscribe(this.unreadIndicatorChannel, this.onMessage);
  }

  @bind
  onMessage(data) {
    this.args.topic.set("unread_by_group_member", data.show_indicator);
  }

  get unreadIndicatorChannel() {
    return `/private-messages/unread-indicator/${this.args.topic.id}`;
  }

  <template>
    {{~#if @topic.unread_by_group_member~}}
      &nbsp;<span
        title={{i18n "topic.unread_indicator"}}
        class="badge badge-notification unread-indicator"
      >
        {{~dIcon "asterisk"~}}
      </span>
    {{~/if~}}
  </template>
}
