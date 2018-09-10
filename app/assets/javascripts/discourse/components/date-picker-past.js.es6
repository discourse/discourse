import DatePicker from "discourse/components/date-picker";

export default DatePicker.extend({
  layoutName: "components/date-picker",

  _opts() {
    return {
      defaultDate:
        moment(this.get("defaultDate"), "YYYY-MM-DD").toDate() || new Date(),
      setDefaultDate: !!this.get("defaultDate"),
      maxDate: new Date()
    };
  }
});
