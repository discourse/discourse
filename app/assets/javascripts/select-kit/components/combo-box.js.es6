import SingleSelectComponent from "select-kit/components/single-select";
import { computed } from "@ember/object";

export default SingleSelectComponent.extend({
  pluginApiIdentifiers: ["combo-box"],
  classNames: ["combobox", "combo-box"],

  selectKitOptions: {
    caretUpIcon: "caret-up",
    caretDownIcon: "caret-down",
    autoFilterable: "autoFilterable",
    clearable: false,
    headerComponent: "combo-box/combo-box-header"
  },

  autoFilterable: computed.gte("content.length", 10)
});
