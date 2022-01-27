import { escapeExpression } from "discourse/lib/utilities";
import SelectedChoiceComponent from "select-kit/components/selected-choice";
import { schedule } from "@ember/runloop";
import { computed } from "@ember/object";

export default SelectedChoiceComponent.extend({
  tagName: "",

  extraClass: "selected-choice-color",

  escapedColor: computed("item", function () {
    const color = `${escapeExpression(this.item?.name || this.item)}`;
    return color.startsWith("#") ? color : `#${color}`;
  }),

  didInsertElement() {
    this._super(...arguments);

    schedule("afterRender", () => {
      const element = document.querySelector(
        `#${this.selectKit.uniqueID} #${this.id}-choice`
      );

      if (!element) {
        return;
      }

      element.style.borderBottomColor = this.escapedColor;
    });
  },
});
