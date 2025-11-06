import { computed } from "@ember/object";
import { schedule } from "@ember/runloop";
import { tagName } from "@ember-decorators/component";
import { escapeExpression } from "discourse/lib/utilities";
import SelectedChoiceComponent from "select-kit/components/selected-choice";

@tagName("")
export default class SelectedChoiceColor extends SelectedChoiceComponent {
  extraClass = "selected-choice-color";

  @computed("item")
  get escapedColor() {
    const color = `${escapeExpression(this.item?.name || this.item)}`;
    return color.startsWith("#") ? color : `#${color}`;
  }

  didInsertElement() {
    super.didInsertElement(...arguments);

    schedule("afterRender", () => {
      const element = document.querySelector(
        `#${this.selectKit.uniqueID} #${this.id}-choice`
      );

      if (!element) {
        return;
      }

      element.style.borderBottomColor = this.escapedColor;
    });
  }
}
