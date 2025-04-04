import { schedule } from "@ember/runloop";
import { classNames } from "@ember-decorators/component";
import { escapeExpression } from "discourse/lib/utilities";
import SelectKitRowComponent from "select-kit/components/select-kit/select-kit-row";

@classNames("create-color-row")
export default class CreateColorRow extends SelectKitRowComponent {
  didReceiveAttrs() {
    super.didReceiveAttrs(...arguments);

    schedule("afterRender", () => {
      const color = escapeExpression(this.rowValue);
      this.element.style.borderLeftColor = color.startsWith("#")
        ? color
        : `#${color}`;
    });
  }

  <template>
    <span>{{this.label}}</span>
  </template>
}
