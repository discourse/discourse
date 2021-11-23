import SelectKitRowComponent from "select-kit/components/select-kit/select-kit-row";
import { escapeExpression } from "discourse/lib/utilities";
import layout from "select-kit/templates/components/create-color-row";
import { schedule } from "@ember/runloop";

export default SelectKitRowComponent.extend({
  layout,
  classNames: ["create-color-row"],

  didReceiveAttrs() {
    this._super(...arguments);

    schedule("afterRender", () => {
      const color = escapeExpression(this.rowValue);
      this.element.style.borderLeftColor = color.startsWith("#")
        ? color
        : `#${color}`;
    });
  },
});
