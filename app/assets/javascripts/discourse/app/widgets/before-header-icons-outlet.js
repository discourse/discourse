import { hbs } from "ember-cli-htmlbars";
import { registerWidgetShim } from "discourse/widgets/render-glimmer";

registerWidgetShim(
  "before-header-icons-outlet",
  "div.before-header-icons-outlet",
  hbs`<PluginOutlet @name="before-header-icons" @outletArgs={{hash attrs=@data}} /> `
);
