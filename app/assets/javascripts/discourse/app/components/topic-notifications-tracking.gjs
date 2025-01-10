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
      @onChange={{@onChange}}
      @levelId={{@levelId}}
      @showCaret={{@showCaret}}
      @showFullTitle={{@showFullTitle}}
      @prefix="topic.notifications"
      @title={{i18n "topic.notifications.title"}}
      class="topic-notifications-tracking"
      @levels={{topicLevels}}
      @suffix={{this.suffix}}
    />
  </template>
}
