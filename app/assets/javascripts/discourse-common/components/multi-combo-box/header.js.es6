import SelectBoxHeaderComponent from "discourse-common/components/select-box/select-box-header";
import { on, observes } from "ember-addons/ember-computed-decorators";

export default SelectBoxHeaderComponent.extend({
  layoutName: "discourse-common/templates/components/multi-combo-box/header",

  classNames: ["multi-combobox-header"]
});
