import "./styles.css";
import { withPluginApi } from "discourse/lib/plugin-api";
import { patchBlockRendering } from "./block-debug/patch.ts";
import { startTrackingFetchedResources } from "./bundle-analyzer/fetched-resources.js";
import { patchConnectors } from "./plugin-outlet-debug/patch.js";
import Toolbar from "./toolbar.gts";

export function init() {
  startTrackingFetchedResources();
  patchConnectors();
  patchBlockRendering();

  withPluginApi((api) => {
    api.renderInOutlet("above-site-header", Toolbar);
  });
}
