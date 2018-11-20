import DatePicker from "discourse/components/date-picker";

export default DatePicker.extend({
  layoutName: "components/date-picker",

  _opts() {
    return {
      defaultDate:
        this.get("defaultDate") ||
        moment()
          .add(1, "day")
          .toDate(),
      setDefaultDate: !!this.get("defaultDate"),
      minDate: new Date()
    };
  }
});
