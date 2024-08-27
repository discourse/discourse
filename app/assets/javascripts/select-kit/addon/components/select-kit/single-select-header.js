import { computed } from "@ember/object";
import { or } from "@ember/object/computed";
import {
  attributeBindings,
  classNames,
  tagName,
} from "@ember-decorators/component";
import I18n from "discourse-i18n";
import SelectKitHeaderComponent from "select-kit/components/select-kit/select-kit-header";

@tagName("summary")
@classNames("single-select-header")
@attributeBindings("name", "ariaLabel:aria-label")
export default class SingleSelectHeader extends SelectKitHeaderComponent {
  @or("selectKit.options.headerAriaLabel", "name") ariaLabel;

  focusIn(event) {
    event.stopImmediatePropagation();

    document.querySelectorAll(".select-kit-header").forEach((header) => {
      if (header !== event.target) {
        header.parentNode.open = false;
      }
    });
  }

  @computed("selectedContent.name")
  get name() {
    if (this.selectedContent) {
      return I18n.t("select_kit.filter_by", {
        name: this.getName(this.selectedContent),
      });
    } else {
      return I18n.t("select_kit.select_to_filter");
    }
  }
}
