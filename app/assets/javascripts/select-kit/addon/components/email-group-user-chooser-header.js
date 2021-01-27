import MultiSelectHeaderComponent from "select-kit/components/multi-select/multi-select-header";
import { computed } from "@ember/object";
import { gt } from "@ember/object/computed";
import { isTesting } from "discourse-common/config/environment";
import layout from "select-kit/templates/components/email-group-user-chooser-header";

export default MultiSelectHeaderComponent.extend({
  layout,
  classNames: ["email-group-user-chooser-header"],
  hasHiddenItems: gt("hiddenItemsCount", 0),

  shownItems: computed("hiddenItemsCount", function () {
    if (
      this.selectKit.noneItem === this.selectedContent ||
      this.hiddenItemsCount === 0
    ) {
      return this.selectedContent;
    }
    return this.selectedContent.slice(
      0,
      this.selectedContent.length - this.hiddenItemsCount
    );
  }),

  didInsertElement() {
    this._super(...arguments);
    this.set("_isRendered", true);
  },

  hiddenItemsCount: computed(
    "selectedContent.[]",
    "selectKit.options.autoWrap",
    "selectKit.isExpanded",
    "_isRendered",
    function () {
      if (
        !this._isRendered ||
        !this.selectKit.options.autoWrap ||
        this.selectKit.isExpanded ||
        this.selectedContent === this.selectKit.noneItem ||
        this.selectedContent.length <= 1 ||
        isTesting()
      ) {
        return 0;
      } else {
        const selectKitHeaderWidth = this.element.offsetWidth;
        const items = this.element.querySelectorAll(".selected-name.choice");
        const input = this.element.querySelector(".filter-input");
        const alreadyHidden = this.element.querySelector(".x-more-item");
        if (alreadyHidden) {
          const hiddenCount = parseInt(
            alreadyHidden.getAttribute("data-hidden-count"),
            10
          );
          return (
            hiddenCount +
            (this.selectedContent.length - (items.length + hiddenCount))
          );
        }
        let total = items[0].offsetWidth + input.offsetWidth;
        let shownItemsCount = 1;
        let shouldHide = false;
        for (let i = 1; i < items.length - 1; i++) {
          const currentWidth = items[i].offsetWidth;
          const nextWidth = items[i + 1].offsetWidth;
          const ratio =
            (total + currentWidth + nextWidth) / selectKitHeaderWidth;
          if (ratio >= 0.95) {
            shouldHide = true;
            break;
          } else {
            shownItemsCount++;
            total += currentWidth;
          }
        }
        return shouldHide ? items.length - shownItemsCount : 0;
      }
    }
  ),
});
