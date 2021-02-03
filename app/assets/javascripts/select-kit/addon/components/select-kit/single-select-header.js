import SelectKitHeaderComponent from "select-kit/components/select-kit/select-kit-header";
import UtilsMixin from "select-kit/mixins/utils";
import layout from "select-kit/templates/components/select-kit/single-select-header";

export default SelectKitHeaderComponent.extend(UtilsMixin, {
  layout,
  classNames: ["single-select-header"],
  attributeBindings: ["role"],

  role: "combobox",
});
