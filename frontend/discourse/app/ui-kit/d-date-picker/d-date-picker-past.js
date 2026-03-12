import DatePicker from "discourse/ui-kit/d-date-picker/d-date-picker";

export default class DatePickerPast extends DatePicker {
  _opts() {
    return {
      defaultDate:
        moment(this.defaultDate, "YYYY-MM-DD").toDate() || new Date(),
      setDefaultDate: !!this.defaultDate,
      maxDate: new Date(),
    };
  }
}
