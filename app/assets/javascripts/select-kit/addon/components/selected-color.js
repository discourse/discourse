import { schedule } from "@ember/runloop";
import { classNames } from "@ember-decorators/component";
import { escapeExpression } from "discourse/lib/utilities";
import SelectedNameComponent from "select-kit/components/selected-name";

@classNames("select-kit-selected-color")
export default class SelectedColor extends SelectedNameComponent {
  didInsertElement() {
    super.didInsertElement(...arguments);

    schedule("afterRender", () => {
      const element = document.querySelector(
        `#${this.selectKit.uniqueID} #${this.id}`
      );

      if (!element) {
        return;
      }

      element.style.borderBottom = "2px solid transparent";
      const color = escapeExpression(this.name);
      element.style.borderBottomColor = `#${color}`;
    });
  }
}
