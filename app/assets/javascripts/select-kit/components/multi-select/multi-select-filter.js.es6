import discourseComputed from "discourse-common/utils/decorators";
const { isEmpty } = Ember;
import SelectKitFilterComponent from "select-kit/components/select-kit/select-kit-filter";

export default SelectKitFilterComponent.extend({
  layoutName: "select-kit/templates/components/select-kit/select-kit-filter",
  classNames: ["multi-select-filter"],

  @discourseComputed("placeholder", "selectKit.hasSelection")
  computedPlaceholder(placeholder, hasSelection) {
    if (hasSelection) return "";
    return isEmpty(placeholder) ? "" : I18n.t(placeholder);
  }
});
