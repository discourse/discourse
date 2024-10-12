import Component from "@glimmer/component";
import { service } from "@ember/service";
import icon from "discourse-common/helpers/d-icon";
import i18n from "discourse-common/helpers/i18n";
import { bind } from "discourse-common/utils/decorators";

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

  get isUnread() {
    return typeof this.args.topic.get("unread_by_group_member") !== "undefined";
  }

  <template>
    {{~#if this.isUnread~}}
      &nbsp;<span
        title={{i18n "topic.unread_indicator"}}
        class="badge badge-notification unread-indicator"
      >
        {{~icon "asterisk"~}}
      </span>
    {{~/if~}}
  </template>
}
