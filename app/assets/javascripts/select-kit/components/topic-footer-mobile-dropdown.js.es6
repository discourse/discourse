import ComboBoxComponent from "select-kit/components/combo-box";

export default ComboBoxComponent.extend({
  pluginApiIdentifiers: ["topic-footer-mobile-dropdown"],
  classNames: ["topic-footer-mobile-dropdown"],

  selectKitOptions: {
    none: "topic.controls",
    filterable: false,
    autoFilterable: false
  },

  actions: {
    onChange(value, item) {
      item.action && item.action();
    }
  }
});
