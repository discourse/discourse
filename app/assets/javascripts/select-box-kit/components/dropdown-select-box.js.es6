import SelectBoxKitComponent from "select-box-kit/components/select-box-kit";
import { on } from "ember-addons/ember-computed-decorators";

export default SelectBoxKitComponent.extend({
  classNames: "dropdown-select-box",
  verticalOffset: 3,
  fullWidthOnMobile: true,
  filterable: false,
  autoFilterable: false,
  headerComponent: "dropdown-select-box/dropdown-select-box-header",
  rowComponent: "dropdown-select-box/dropdown-select-box-row",
  showFullTitle: true,

  @on("didReceiveAttrs")
  _setDropdownSelectBoxComponentOptions() {
    this.get("headerComponentOptions").setProperties({showFullTitle: this.get("showFullTitle")});
  },

  clickOutside() {
    if (this.get("isExpanded") === false) { return; }
    this.close();
  },

  didSelect() {
    this._super();
    this.blur();
  }
});
