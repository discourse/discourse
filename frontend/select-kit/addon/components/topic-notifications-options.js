import { computed } from "@ember/object";
import { classNames } from "@ember-decorators/component";
import { topicLevels } from "discourse/lib/notification-levels";
import NotificationsButtonComponent from "select-kit/components/notifications-button";
import {
  pluginApiIdentifiers,
  selectKitOptions,
} from "select-kit/components/select-kit";

@classNames("topic-notifications-options")
@selectKitOptions({
  i18nPrefix: "topic.notifications",
  i18nPostfix: "i18nPostfix",
  showCaret: true,
})
@pluginApiIdentifiers("topic-notifications-options")
export default class TopicNotificationsOptions extends NotificationsButtonComponent {
  content = topicLevels;

  @computed("topic.archetype")
  get i18nPostfix() {
    return this.topic.archetype === "private_message" ? "_pm" : "";
  }
}
