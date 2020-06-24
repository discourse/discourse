import I18n from "I18n";
import TextField from "discourse/components/text-field";
import discourseComputed from "discourse-common/utils/decorators";

export default TextField.extend({
  classNameBindings: ["invalid"],

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
    }
  },

  @discourseComputed("placeholderKey")
  placeholder(key) {
    return key ? I18n.t(key) : "";
  }
});
