import SingleSelectComponent from "select-kit/components/single-select";
import { on } from "ember-addons/ember-computed-decorators";

export default SingleSelectComponent.extend({
  pluginApiIdentifiers: ["dropdown-select-box"],
  classNames: "dropdown-select-box",
  verticalOffset: 3,
  fullWidthOnMobile: true,
  filterable: false,
  autoFilterable: false,
  headerComponent: "dropdown-select-box/dropdown-select-box-header",
  rowComponent: "dropdown-select-box/dropdown-select-box-row",
  showFullTitle: true,
  allowInitialValueMutation: false,

  @on("didUpdateAttrs", "init")
  _setDropdownSelectBoxComponentOptions() {
    this.headerComponentOptions.setProperties({
      showFullTitle: this.showFullTitle
    });
  },

  didClickOutside() {
    if (!this.isExpanded) return;
    this.close();
  },

  didSelect() {
    this._super(...arguments);
    this.close();
  }
});
