import { hbs } from "ember-cli-htmlbars";
import RenderGlimmer from "discourse/widgets/render-glimmer";
import { createWidget } from "discourse/widgets/widget";

createWidget("post-user-status", {
  tagName: "span.user-status-message-wrap",

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
