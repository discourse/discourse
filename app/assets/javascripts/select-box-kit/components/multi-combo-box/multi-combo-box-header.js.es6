import { on } from "ember-addons/ember-computed-decorators";
import computed from "ember-addons/ember-computed-decorators";
import SelectBoxKitHeaderComponent from "select-box-kit/components/select-box-kit/select-box-kit-header";

export default SelectBoxKitHeaderComponent.extend({
  attributeBindings: ["names:data-name"],
  classNames: "multi-combo-box-header",
  layoutName: "select-box-kit/templates/components/multi-combo-box/multi-combo-box-header",
  selectedNameComponent: Ember.computed.alias("options.selectedNameComponent"),

  @on("didRender")
  _positionFilter() {
    if (this.get("shouldDisplayFilter") === false) { return; }

    const $filter = this.$(".filter");
    $filter.width(0);

    const leftHeaderOffset = this.$().offset().left;
    const leftFilterOffset = $filter.offset().left;
    const offset = leftFilterOffset - leftHeaderOffset;
    const width = this.$().outerWidth(false);
    const availableSpace = width - offset;
    const $choices = $filter.parent(".choices");
    const parentRightPadding = parseInt($choices.css("padding-right") , 10);
    $filter.width(availableSpace - parentRightPadding * 4);
  },

  @computed("selectedContent.[]")
  names(selectedContent) { return selectedContent.map(sc => sc.name).join(","); }
});
