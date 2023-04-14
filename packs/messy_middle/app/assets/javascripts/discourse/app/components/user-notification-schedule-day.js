import Component from "@ember/component";
import { i18n } from "discourse/lib/computed";

export default Component.extend({
  tagName: "",
  dayLabel: i18n("day", "user.notification_schedule.%@"),
});
