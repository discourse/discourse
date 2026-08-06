import "./styles.css";
import { withPluginApi } from "discourse/lib/plugin-api";
import { i18n } from "discourse-i18n";
import { installA11yTap } from "./a11y/instrumentation";
import A11yPanel from "./a11y/panel";
import { patchBlockRendering } from "./block-debug/patch";
import { registerDockPanel } from "./dock";
import { patchConnectors } from "./plugin-outlet-debug/patch";
import Toolbar from "./toolbar";

export function init() {
  installA11yTap();
  registerDockPanel("a11y", {
    label: i18n("dev_tools.a11y.title"),
    component: A11yPanel,
  });

  patchConnectors();
  patchBlockRendering();

  withPluginApi((api) => {
    api.renderInOutlet("above-site-header", Toolbar);
  });
}
