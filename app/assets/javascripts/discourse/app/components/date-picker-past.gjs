import DatePicker from "discourse/components/date-picker";

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
