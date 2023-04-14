import { hbs } from "ember-cli-htmlbars";
import { registerWidgetShim } from "discourse/widgets/render-glimmer";

registerWidgetShim(
  "header-bootstrap-mode",
  "div.d-header-mode",
  hbs`<BootstrapModeNotice />`
);
