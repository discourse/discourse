import Component from "@glimmer/component";
import NotificationsTracking from "discourse/components/notifications-tracking";
import { topicLevels } from "discourse/lib/notification-levels";
import { i18n } from "discourse-i18n";

export default class TopicNotificationsTracking extends Component {
  get suffix() {
    return this.args.topic?.archetype === "private_message" ? "_pm" : "";
  }

  <template>
    <NotificationsTracking
      class="topic-notifications-tracking"
      @contentClass={{@contentClass}}
      @levelId={{@levelId}}
      @levels={{topicLevels}}
      @onChange={{@onChange}}
      @prefix="topic.notifications"
      @showCaret={{@showCaret}}
      @showFullTitle={{@showFullTitle}}
      @suffix={{this.suffix}}
      @title={{i18n "topic.notifications.title"}}
      @topic={{@topic}}
    />
  </template>
}
