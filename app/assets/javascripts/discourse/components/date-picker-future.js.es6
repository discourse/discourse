import DatePicker from "discourse/components/date-picker";

export default DatePicker.extend({
  layoutName: "components/date-picker",

  _opts() {
    return {
      defaultDate: moment().add(1, "day").toDate(),
      minDate: new Date(),
    };
  }
});
