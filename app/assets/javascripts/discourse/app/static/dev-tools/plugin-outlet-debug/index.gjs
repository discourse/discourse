import curryComponent from "ember-curry-component";
import { _setOutletDebugCallback } from "discourse/lib/plugin-connectors";
import { getOwnerWithFallback } from "discourse-common/lib/get-owner";
import devToolsState from "../state";
import OutletInfoComponent from "./outlet-info";

const SKIP_EXISTING_FOR_OUTLETS = [
  "home-logo-wrapper", // Wrapper outlet used by chat, so very likely to be present
];

export function patchConnectors() {
  _setOutletDebugCallback((outletName, existing) => {
    existing ||= [];

    if (!devToolsState.pluginOutletDebug) {
      return existing;
    }

    if (SKIP_EXISTING_FOR_OUTLETS.includes(outletName)) {
      existing = [];
    }

    const componentClass = curryComponent(
      OutletInfoComponent,
      { outletName },
      getOwnerWithFallback()
    );

    return [{ componentClass }, ...existing];
  });
}
