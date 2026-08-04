import "./styles.css";
import { withPluginApi } from "discourse/lib/plugin-api";
import { patchBlockRendering } from "./block-debug/patch";
import { patchConnectors } from "./plugin-outlet-debug/patch";
import Toolbar from "./toolbar";

export function init() {
  patchConnectors();
  patchBlockRendering();

  // TODO(devxp-typescript-pending): `plugin-api` is untyped JavaScript and does
  // not export the type of the API object, so only the member used here is
  // described. Drop this once the plugin API is authored in TypeScript.
  withPluginApi(
    (api: { renderInOutlet: (name: string, component: unknown) => void }) => {
      api.renderInOutlet("above-site-header", Toolbar);
    }
  );
}
