import { on } from "ember-addons/ember-computed-decorators";
import computed from "ember-addons/ember-computed-decorators";
import SelectBoxKitHeaderComponent from "select-box-kit/components/select-box-kit/select-box-kit-header";

export default SelectBoxKitHeaderComponent.extend({
  layoutName: "select-box-kit/templates/components/multi-combo-box/multi-combo-box-header",
  classNames: "multi-combobox-header",
  attributeBindings: ["names:data-name"],

  @on("didRender")
  _positionFilter() {
    this.$(".filter").width(0);

    const leftHeaderOffset = this.$().offset().left;
    const leftFilterOffset = this.$(".filter").offset().left;
    const offset = leftFilterOffset - leftHeaderOffset;
    const width = this.$().outerWidth(false);
    const availableSpace = width - offset;

    this.$(".filter").width(availableSpace - 8);
  },

  @computed("selectedContent.[]")
  names(selectedContent) {
    return selectedContent.map(sc => sc.name).join(",");
  }
});
