import SelectedNameComponent from "select-kit/components/selected-name";
import { escapeExpression } from "discourse/lib/utilities";
import { schedule } from "@ember/runloop";

export default SelectedNameComponent.extend({
  classNames: ["select-kit-selected-color"],

  didInsertElement() {
    this._super(...arguments);

    schedule("afterRender", () => {
      const color = escapeExpression(this.name),
        el = document.querySelector(`[data-value="${color}"]`);

      if (el) {
        el.style.borderBottom = "2px solid transparent";
        el.style.borderBottomColor = `#${color}`;
      }
    });
  },
});
