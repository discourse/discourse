import curryComponent from "ember-curry-component";
import { getOwnerWithFallback } from "discourse/lib/get-owner";
import { _setIncludeDeprecatedArgsProperty } from "discourse/lib/outlet-args";
import { _setOutletDebugCallback } from "discourse/lib/plugin-connectors";
import devToolsState from "../state";
import OutletInfoComponent from "./outlet-info";

const SKIP_EXISTING_FOR_OUTLETS = [
  "home-logo-wrapper", // Wrapper outlet used by chat, so very likely to be present
];

export function patchConnectors() {
  // Enable including raw deprecatedArgs in outletArgsWithDeprecations
  // so ArgsTable can display deprecation info without separate prop passing
  _setIncludeDeprecatedArgsProperty(true);

  _setOutletDebugCallback((outletName, existing, { outletArgs } = {}) => {
    existing ||= [];

    if (!devToolsState.pluginOutletDebug) {
      return existing;
    }

    if (SKIP_EXISTING_FOR_OUTLETS.includes(outletName)) {
      existing = [];
    }

    const componentClass = curryComponent(
      OutletInfoComponent,
      { outletName, outletArgs },
      getOwnerWithFallback()
    );

    return [{ componentClass }, ...existing];
  });
}
