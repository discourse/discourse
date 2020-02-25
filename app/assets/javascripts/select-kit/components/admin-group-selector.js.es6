import MultiSelectComponent from "select-kit/components/multi-select";

export default MultiSelectComponent.extend({
  pluginApiIdentifiers: ["admin-group-selector"],
  classNames: ["admin-group-selector"],
  selectKitOptions: {
    allowAny: false
  }
});
