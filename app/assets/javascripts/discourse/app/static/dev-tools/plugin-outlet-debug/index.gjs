import curryComponent from "ember-curry-component";
import {
  _unsafe_get_connector_cache,
  _unsafe_set_connector_cache,
} from "discourse/lib/plugin-connectors";
import { getOwnerWithFallback } from "discourse-common/lib/get-owner";
import OutletInfoComponent from "./outlet-info";

const alreadyPatched = new Set();

export function patchConnectors() {
  const oldConnectorCache = _unsafe_get_connector_cache() || {};

  const connectorCacheProxy = new Proxy(oldConnectorCache, {
    get: function (target, prop) {
      if (!alreadyPatched.has(prop)) {
        alreadyPatched.add(prop);
        target[prop] ||= [];
        target[prop].push({
          connectorClass: OutletInfoComponent,
          componentClass: curryComponent(
            OutletInfoComponent,
            { outletName: prop },
            getOwnerWithFallback()
          ),
        });
      }

      return target[prop];
    },
  });

  _unsafe_set_connector_cache(connectorCacheProxy);
}
