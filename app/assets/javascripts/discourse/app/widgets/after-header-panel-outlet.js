import { hbs } from "ember-cli-htmlbars";
import { registerWidgetShim } from "discourse/widgets/render-glimmer";

registerWidgetShim(
  "after-header-panel-outlet",
  "div.after-header-panel-outlet",
  hbs`<PluginOutlet @name="after-header-panel" @outletArgs={{hash topic=@data.topic}} /> `
);
