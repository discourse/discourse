import DatePicker from "discourse/components/date-picker";

export default DatePicker.extend({
  layoutName: "components/date-picker",

  _opts() {
    return {
      defaultDate: new Date(this.get("defaultDate")) || new Date(),
      setDefaultDate: !!this.get("defaultDate"),
      maxDate: new Date()
    };
  }
});
