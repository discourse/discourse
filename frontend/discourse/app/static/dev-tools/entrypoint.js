import "./styles.css";
import { withPluginApi } from "discourse/lib/plugin-api";
import { patchConnectors } from "./plugin-outlet-debug/patch";
import Toolbar from "./toolbar";

export function init() {
  patchConnectors();

  withPluginApi((api) => {
    api.renderInOutlet("above-site-header", Toolbar);
  });
}
