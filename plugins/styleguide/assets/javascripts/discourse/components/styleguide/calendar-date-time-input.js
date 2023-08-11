import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";

export default class StyleguideCalendarDateTimeInput extends Component {
  @service currentUser;

  @tracked dateFormat = "YYYY-MM-DD";
  @tracked timeFormat = "HH:mm:ss";
  @tracked date = null;
  @tracked time = null;
  @tracked minDate = null;

  @action
  changeDate(date) {
    this.date = date;
  }

  @action
  changeTime(time) {
    this.time = time;
  }
}
