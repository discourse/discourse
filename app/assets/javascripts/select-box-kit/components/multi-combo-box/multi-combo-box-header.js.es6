import { on } from "ember-addons/ember-computed-decorators";
import computed from "ember-addons/ember-computed-decorators";
import SelectBoxKitHeaderComponent from "select-box-kit/components/select-box-kit/select-box-kit-header";

export default SelectBoxKitHeaderComponent.extend({
  attributeBindings: ["names:data-name"],
  classNames: "multi-combobox-header",
  layoutName: "select-box-kit/templates/components/multi-combo-box/multi-combo-box-header",

  @computed("filter", "selectedContent.[]", "isFocused", "selectBoxIsExpanded")
  shouldDisplayFilterPlaceholder(filter, selectedContent, isFocused) {
    if (Ember.isEmpty(selectedContent)) {
      if (filter.length > 0) { return false; }
      if (isFocused === true) { return false; }
      return true;
    }

    return false;
  },

  @on("didRender")
  _positionFilter() {
    this.$(".filter").width(0);

    const leftHeaderOffset = this.$().offset().left;
    const leftFilterOffset = this.$(".filter").offset().left;
    const offset = leftFilterOffset - leftHeaderOffset;
    const width = this.$().outerWidth(false);
    const availableSpace = width - offset;

    // TODO: avoid magic number 8
    // TODO: make sure the filter doesn’t end up being very small
    this.$(".filter").width(availableSpace - 8);
  },

  @computed("selectedContent.[]")
  names(selectedContent) {
    return selectedContent.map(sc => sc.name).join(",");
  }
});
