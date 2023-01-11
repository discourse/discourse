import ComboBoxComponent from "select-kit/components/combo-box";

export default ComboBoxComponent.extend({
  pluginApiIdentifiers: ["timezone-input"],
  classNames: ["timezone-input"],

  selectKitOptions: {
    filterable: true,
    allowAny: false,
  },

  get nameProperty() {
    return this.isLocalized ? "name" : null;
  },

  get valueProperty() {
    return this.isLocalized ? "value" : null;
  },

  get content() {
    return this.isLocalized ? moment.tz.localizedNames() : moment.tz.names();
  },

  get isLocalized() {
    return (
      moment.locale() !== "en" && typeof moment.tz.localizedNames === "function"
    );
  },
});
