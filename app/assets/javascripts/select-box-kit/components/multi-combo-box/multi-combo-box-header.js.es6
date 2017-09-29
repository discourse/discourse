import SelectBoxKitHeaderComponent from "select-box-kit/components/select-box-kit/select-box-kit-header";
import { on, observes } from "ember-addons/ember-computed-decorators";

export default SelectBoxKitHeaderComponent.extend({
  layoutName: "select-box-kit/templates/components/multi-combo-box/multi-combo-box-header",

  classNames: ["multi-combobox-header"]
});
