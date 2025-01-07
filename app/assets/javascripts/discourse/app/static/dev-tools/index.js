import "./styles.css";
import { withPluginApi } from "discourse/lib/plugin-api";
import { patchConnectors } from "./plugin-outlet-debug";
import Toolbar from "./toolbar";

export function init() {
  patchConnectors();

  withPluginApi("0.8", (api) => {
    api.renderInOutlet("above-site-header", Toolbar);
  });
}
