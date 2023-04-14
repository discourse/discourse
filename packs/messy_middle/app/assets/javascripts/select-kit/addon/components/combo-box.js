import SingleSelectComponent from "select-kit/components/single-select";
import { gte } from "@ember/object/computed";

export default SingleSelectComponent.extend({
  pluginApiIdentifiers: ["combo-box"],
  classNames: ["combobox", "combo-box"],

  selectKitOptions: {
    caretUpIcon: "caret-up",
    caretDownIcon: "caret-down",
    autoFilterable: "autoFilterable",
    clearable: false,
    headerComponent: "combo-box/combo-box-header",
  },

  autoFilterable: gte("content.length", 10),
});
