import { on } from "ember-addons/ember-computed-decorators";
import computed from "ember-addons/ember-computed-decorators";
import SelectKitHeaderComponent from "select-kit/components/select-kit/select-kit-header";

export default SelectKitHeaderComponent.extend({
  attributeBindings: [
    "label:title",
    "label:aria-label",
    "names:data-name",
    "values:data-value"
  ],
  classNames: "multi-select-header",
  layoutName:
    "select-kit/templates/components/multi-select/multi-select-header",
  selectedNameComponent: Ember.computed.alias("options.selectedNameComponent"),

  ariaLabel: Ember.computed.or("computedContent.ariaLabel", "title", "names"),

  title: Ember.computed.or("computedContent.title", "names"),

  @on("didRender")
  _positionFilter() {
    if (!this.get("shouldDisplayFilter")) return;

    const $filter = this.$(".filter");
    $filter.width(0);

    const leftHeaderOffset = this.$().offset().left;
    const leftFilterOffset = $filter.offset().left;
    const offset = leftFilterOffset - leftHeaderOffset;
    const width = this.$().outerWidth(false);
    const availableSpace = width - offset;
    const $choices = $filter.parent(".choices");
    const parentRightPadding = parseInt($choices.css("padding-right"), 10);
    $filter.width(availableSpace - parentRightPadding * 4);
  },

  @computed("computedContent.selection.[]")
  names(selection) {
    return Ember.makeArray(selection)
      .map(s => s.name)
      .join(",");
  },

  @computed("computedContent.selection.[]")
  values(selection) {
    return Ember.makeArray(selection)
      .map(s => s.value)
      .join(",");
  }
});
