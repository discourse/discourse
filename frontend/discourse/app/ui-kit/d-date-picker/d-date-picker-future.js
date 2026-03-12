import DatePicker from "discourse/ui-kit/d-date-picker/d-date-picker";

export default class DatePickerFuture extends DatePicker {
  _opts() {
    return {
      defaultDate: this.defaultDate || moment().add(1, "day").toDate(),
      setDefaultDate: !!this.defaultDate,
      minDate: this.minDate || moment().toDate(),
    };
  }
}
