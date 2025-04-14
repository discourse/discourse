import { action } from "@ember/object";
import { isEmpty } from "@ember/utils";
import { classNames } from "@ember-decorators/component";
import discourseComputed from "discourse/lib/decorators";
import SelectKitFilterComponent from "select-kit/components/select-kit/select-kit-filter";

@classNames("multi-select-filter")
export default class MultiSelectFilter extends SelectKitFilterComponent {
  @discourseComputed("placeholder", "selectKit.hasSelection")
  computedPlaceholder(placeholder, hasSelection) {
    if (this.hidePlaceholderWithSelection && hasSelection) {
      return "";
    }

    return isEmpty(placeholder) ? "" : placeholder;
  }

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
  }
}
