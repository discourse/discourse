import hbs from "discourse/widgets/hbs-compiler";
import { createWidget } from "discourse/widgets/widget";

createWidget("menu-panel", {
  tagName: "div.menu-panel",
  template: hbs`
    <div class='panel-body'>
      <div class='panel-body-contents'>
        {{yield}}
      </div>
    </div>
  `,

  buildAttributes(attrs) {
    if (attrs.maxWidth) {
      return { "data-max-width": attrs.maxWidth };
    }
  },
});
