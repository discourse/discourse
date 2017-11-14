import { on } from "ember-addons/ember-computed-decorators";
import computed from "ember-addons/ember-computed-decorators";
import SelectKitHeaderComponent from "select-kit/components/select-kit/select-kit-header";

export default SelectKitHeaderComponent.extend({
  attributeBindings: ["names:data-name"],
  classNames: "multi-select-header",
  layoutName: "select-kit/templates/components/multi-select/multi-select-header",
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

  @computed("computedContent.selectedComputedContents.[]")
  names(selectedComputedContents) {
    return Ember.makeArray(selectedComputedContents).map(sc => sc.name).join(",");
  }
});
