import DropdownSelectBoxRowComponent from "select-kit/components/dropdown-select-box/dropdown-select-box-row";
import computed from "ember-addons/ember-computed-decorators";

export default DropdownSelectBoxRowComponent.extend({
  layoutName:
    "select-kit/templates/components/period-chooser/period-chooser-row",
  classNames: "period-chooser-row",

  @computed("computedContent")
  title(computedContent) {
    return I18n.t(`filters.top.${computedContent.name || "this_week"}`).title;
  }
});
