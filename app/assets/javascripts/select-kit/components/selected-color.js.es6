import SelectedNameComponent from "select-kit/components/selected-name";
import { escapeExpression } from "discourse/lib/utilities";
import { schedule } from "@ember/runloop";

export default SelectedNameComponent.extend({
  classNames: ["select-kit-selected-color"],

  didReceiveAttrs() {
    this._super(...arguments);

    schedule("afterRender", () => {
      const color = escapeExpression(this.name);
      this.element.style.borderBottomColor = `#${color}`;
    });
  }
});
