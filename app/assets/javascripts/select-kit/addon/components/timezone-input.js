import ComboBoxComponent from "select-kit/components/combo-box";
import { computed } from "@ember/object";

export default ComboBoxComponent.extend({
  pluginApiIdentifiers: ["timezone-input"],
  classNames: ["timezone-input"],

  selectKitOptions: {
    filterable: true,
    allowAny: false,
  },

  nameProperty: computed(function () {
    return this.isLocalized() ? "name" : null;
  }),

  valueProperty: computed(function () {
    return this.isLocalized() ? "value" : null;
  }),

  content: computed(function () {
    return this.isLocalized() ? moment.tz.localizedNames() : moment.tz.names();
  }),

  isLocalized() {
    return (
      moment.locale() !== "en" && typeof moment.tz.localizedNames === "function"
    );
  },
});
