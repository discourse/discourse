import MultiSelectComponent from "select-kit/components/multi-select";

export default MultiSelectComponent.extend({
  pluginApiIdentifiers: ["group-chooser"],
  classNames: ["group-chooser"],
  selectKitOptions: {
    allowAny: false,
  },
});
