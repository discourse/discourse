import ComboBoxComponent from "select-kit/components/combo-box";
import { computed } from "@ember/object";

export default ComboBoxComponent.extend({
  pluginApiIdentifiers: ["timezone-input"],
  classNames: ["timezone-input"],
  nameProperty: null,
  valueProperty: null,

  selectKitOptions: {
    filterable: true,
    allowAny: false
  },

  content: computed(function() {
    if (
      moment.locale() !== "en" &&
      typeof moment.tz.localizedNames === "function"
    ) {
      return moment.tz.localizedNames().mapBy("value");
    } else {
      return moment.tz.names();
    }
  })
});
