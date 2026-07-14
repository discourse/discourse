import DDatePicker from "discourse/ui-kit/d-date-picker";

export default class DatePickerFuture extends DDatePicker {
  _opts() {
    return {
      defaultDate: this.defaultDate || moment().add(1, "day").toDate(),
      setDefaultDate: !!this.defaultDate,
      minDate: this.minDate || moment().toDate(),
    };
  }
}
