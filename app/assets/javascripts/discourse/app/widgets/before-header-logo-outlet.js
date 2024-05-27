import { hbs } from "ember-cli-htmlbars";
import { registerWidgetShim } from "discourse/widgets/render-glimmer";

registerWidgetShim(
  "before-header-logo-outlet",
  "div.before-header-logo-outlet",
  hbs`<PluginOutlet @name="before-header-logo" @outletArgs={{hash attrs=@data}} /> `
);
