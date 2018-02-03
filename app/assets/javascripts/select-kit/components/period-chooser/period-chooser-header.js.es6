import DropdownSelectBoxHeaderomponent from "select-kit/components/dropdown-select-box/dropdown-select-box-header";
import computed from 'ember-addons/ember-computed-decorators';

export default DropdownSelectBoxHeaderomponent.extend({
  layoutName: "select-kit/templates/components/period-chooser/period-chooser-header",
  classNames: "period-chooser-header",

  @computed("isExpanded")
  caretIcon(isExpanded) {
    return isExpanded ? "caret-up" : "caret-down";
  }
});
