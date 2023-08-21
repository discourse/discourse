import SelectKitFilterComponent from "select-kit/components/select-kit/select-kit-filter";
import { isEmpty } from "@ember/utils";
import discourseComputed from "discourse-common/utils/decorators";
import { action } from "@ember/object";

export default SelectKitFilterComponent.extend({
  classNames: ["multi-select-filter"],

  @discourseComputed("placeholder", "selectKit.hasSelection")
  computedPlaceholder(placeholder, hasSelection) {
    if (this.hidePlaceholderWithSelection && hasSelection) {
      return "";
    }

    return isEmpty(placeholder) ? "" : placeholder;
  },

  @action
  onPaste(event) {
    const data = event?.clipboardData;

    if (!data) {
      return;
    }

    const parts = data.getData("text").split("|").filter(Boolean);

    if (parts.length > 1) {
      event.stopPropagation();
      event.preventDefault();

      this.selectKit.append(parts);

      return false;
    }
  },
});
