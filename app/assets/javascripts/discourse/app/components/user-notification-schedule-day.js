import Component from "@ember/component";
import I18n from "I18n";
import discourseComputed from "discourse-common/utils/decorators";

export default Component.extend({
  tagName: "",

  @discourseComputed("day")
  dayLabel(day) {
    return I18n.t(`user.notification_schedule.${day}`);
  },
});
