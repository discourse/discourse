import BaseField from "./da-base-field";
import { action, computed } from "@ember/object";

export default class DateTimeField extends BaseField {
  @action
  convertToUniversalTime(date) {
    return (
      date && this.set("field.metadata.value", moment(date).utc().format())
    );
  }

  @computed("field.metadata.value")
  get localTime() {
    return (
      this.field.metadata.value &&
      moment(this.field.metadata.value)
        .local()
        .format(moment.HTML5_FMT.DATETIME_LOCAL)
    );
  }
}
