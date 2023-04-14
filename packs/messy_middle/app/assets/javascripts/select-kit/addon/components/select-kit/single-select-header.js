import { computed } from "@ember/object";
import { or } from "@ember/object/computed";
import SelectKitHeaderComponent from "select-kit/components/select-kit/select-kit-header";
import UtilsMixin from "select-kit/mixins/utils";
import layout from "select-kit/templates/components/select-kit/single-select-header";
import I18n from "I18n";

export default SelectKitHeaderComponent.extend(UtilsMixin, {
  tagName: "summary",
  layout,
  classNames: ["single-select-header"],
  attributeBindings: ["name", "ariaLabel:aria-label"],

  ariaLabel: or("selectKit.options.headerAriaLabel", "name"),

  focusIn(event) {
    event.stopImmediatePropagation();

    document.querySelectorAll(".select-kit-header").forEach((header) => {
      if (header !== event.target) {
        header.parentNode.open = false;
      }
    });
  },

  name: computed("selectedContent.name", function () {
    if (this.selectedContent) {
      return I18n.t("select_kit.filter_by", {
        name: this.getName(this.selectedContent),
      });
    } else {
      return I18n.t("select_kit.select_to_filter");
    }
  }),
});
