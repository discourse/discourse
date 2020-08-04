import SelectKitHeaderComponent from "select-kit/components/select-kit/select-kit-header";
import UtilsMixin from "select-kit/mixins/utils";

export default SelectKitHeaderComponent.extend(UtilsMixin, {
  layoutName: "select-kit/templates/components/select-kit/single-select-header",
  classNames: ["single-select-header"]
});
