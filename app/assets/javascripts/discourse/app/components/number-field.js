import I18n from "I18n";
import TextField from "discourse/components/text-field";
import discourseComputed from "discourse-common/utils/decorators";

export default TextField.extend({
  classNameBindings: ["invalid"],

  keyDown: function (e) {
    const key = e.which;

    return (
      key === 13 || // Enter
      key === 8 || // Backspace
      key === 9 || // Tab
      key === 46 || // Delete
      ((key === 109 || key === 189) && // Negative sign
        parseInt(this.get("min"), 10) < 0) ||
      (key >= 35 && key <= 40) || // Cursor keys
      (key >= 48 && key <= 57) || // Numbers
      (key >= 96 && key <= 105) // Numpad
    );
  },

  @discourseComputed("number")
  value: {
    get(number) {
      return parseInt(number, 10);
    },
    set(value) {
      const num = parseInt(value, 10);
      if (isNaN(num)) {
        this.set("invalid", true);
        return value;
      } else {
        this.set("invalid", false);
        this.set("number", num);
        return num.toString();
      }
    },
  },

  @discourseComputed("placeholderKey")
  placeholder(key) {
    return key ? I18n.t(key) : "";
  },
});
