import { hbs } from "ember-cli-htmlbars";
import { registerWidgetShim } from "discourse/widgets/render-glimmer";

registerWidgetShim(
  "before-header-panel-outlet",
  "div.before-header-panel-outlet",
  hbs`<PluginOutlet @name="before-header-panel" @outletArgs={{hash attrs=@data}} /> `
);
