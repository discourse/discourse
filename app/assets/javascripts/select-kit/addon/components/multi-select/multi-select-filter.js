import I18n from "I18n";
import SelectKitFilterComponent from "select-kit/components/select-kit/select-kit-filter";
const { isEmpty } = Ember;
import discourseComputed from "discourse-common/utils/decorators";
import layout from "select-kit/templates/components/select-kit/select-kit-filter";

export default SelectKitFilterComponent.extend({
  layout,
  classNames: ["multi-select-filter"],

  @discourseComputed("placeholder", "selectKit.hasSelection")
  computedPlaceholder(placeholder, hasSelection) {
    if (hasSelection) {
      return "";
    }
    return isEmpty(placeholder) ? "" : I18n.t(placeholder);
  },
});
