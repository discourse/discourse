import Component from "@ember/component";
import { action } from "@ember/object";
import { durationTextFromSeconds } from "discourse/helpers/slow-mode";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseComputed from "discourse/lib/decorators";
import Topic from "discourse/models/topic";

export default class SlowModeInfo extends Component {
  @discourseComputed("topic.slow_mode_seconds")
  durationText(seconds) {
    return durationTextFromSeconds(seconds);
  }

  @discourseComputed("topic.slow_mode_seconds", "topic.closed")
  showSlowModeNotice(seconds, closed) {
    return seconds > 0 && !closed;
  }

  @action
  disableSlowMode() {
    Topic.setSlowMode(this.topic.id, 0)
      .catch(popupAjaxError)
      .then(() => this.set("topic.slow_mode_seconds", 0));
  }
}
