import Component from "@ember/component";
import { tagName } from "@ember-decorators/component";
import { i18n } from "discourse/lib/computed";

@tagName("")
export default class UserNotificationScheduleDay extends Component {
  @i18n("day", "user.notification_schedule.%@") dayLabel;
}
