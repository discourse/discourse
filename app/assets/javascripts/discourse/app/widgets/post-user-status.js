import { createWidget } from "discourse/widgets/widget";
import RenderGlimmer from "discourse/widgets/render-glimmer";
import { hbs } from "ember-cli-htmlbars";

createWidget("post-user-status", {
  html(attrs) {
    return [
      new RenderGlimmer(
        this,
        "div",
        hbs`<UserStatusMessage @status={{@data.attrs}} />`,
        {
          attrs,
        }
      ),
    ];
  },
});
