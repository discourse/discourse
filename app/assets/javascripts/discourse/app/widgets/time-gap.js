import { hbs } from "ember-cli-htmlbars";
import RenderGlimmer from "discourse/widgets/render-glimmer";
import { createWidget } from "discourse/widgets/widget";

createWidget("time-gap", {
  tagName: "div.time-gap.small-action",

  html(attrs) {
    return [
      new RenderGlimmer(
        this,
        "div.time-gap-widget",
        hbs`<TimeGap @daysSince={{@data.attrs.daysSince}} />`,
        {
          attrs,
        }
      ),
    ];
  },
});
