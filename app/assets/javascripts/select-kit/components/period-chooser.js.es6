import DropdownSelectBoxComponent from "select-kit/components/dropdown-select-box";
import computed, { on } from "ember-addons/ember-computed-decorators";

export default DropdownSelectBoxComponent.extend({
  classNames: ["period-chooser"],
  rowComponent: "period-chooser/period-chooser-row",
  headerComponent: "period-chooser/period-chooser-header",
  content: Ember.computed.alias("site.periods"),
  value: Ember.computed.alias("period"),
  isHidden: Ember.computed.alias("showPeriods"),

  @computed("isExpanded")
  caretIcon(isExpanded) {
    return isExpanded ? "caret-up" : "caret-down";
  },

  @on("didReceiveAttrs")
  _setFullDay() {
    this.get("headerComponentOptions").setProperties({
      fullDay: this.get("fullDay")
    });
    this.get("rowComponentOptions").setProperties({
      fullDay: this.get("fullDay")
    });
  },

  actions: {
    onSelect() {
      this.sendAction("action", this.get("computedValue"));
    }
  }
});
