import "./styles.css";
import { devToolsDAG } from "discourse/lib/dev-tools/registry";
import { withPluginApi } from "discourse/lib/plugin-api";
import BlockDebugButton from "./block-debug/button";
import { patchBlockRendering } from "./block-debug/patch";
import MessageBusButton from "./message-bus/button";
import { install as observeMessageBus } from "./message-bus/instrumentation";
import PluginOutletDebugButton from "./plugin-outlet-debug/button";
import { patchConnectors } from "./plugin-outlet-debug/patch";
import SafeModeButton from "./safe-mode/button";
import Toolbar from "./toolbar";
import UpcomingChangesDebugButton from "./upcoming-changes-debug/button";
import VerboseLocalizationButton from "./verbose-localization/button";

/**
 * The tools shipped with Discourse, in the order they appear in the toolbar.
 *
 * The last entry is also the anchor that externally registered tools default
 * to being placed after. Renaming it means updating `LAST_CORE_TOOL` in
 * `discourse/lib/dev-tools/registry`.
 */
const CORE_TOOLS = [
  ["plugin-outlet-debug", PluginOutletDebugButton],
  ["block-debug", BlockDebugButton],
  ["upcoming-changes-debug", UpcomingChangesDebugButton],
  ["safe-mode", SafeModeButton],
  ["verbose-localization", VerboseLocalizationButton],
  ["message-bus", MessageBusButton],
];

/**
 * Adds the core tools to the registry.
 *
 * Each tool is positioned explicitly against the previous one rather than
 * relying on the order they are added in. Tools registered through the plugin
 * API are added earlier in the boot sequence, so insertion order alone would
 * let an externally registered tool appear among the core buttons.
 *
 * Adding a key that is already present is a no-op, so calling this more than
 * once leaves the registry unchanged.
 */
function seedCoreTools() {
  const registry = devToolsDAG();
  let previous;

  for (const [id, component] of CORE_TOOLS) {
    registry.add(id, component, previous ? { after: previous } : {});
    previous = id;
  }
}

export function init() {
  seedCoreTools();

  // Installed at load rather than when the panel is opened, so that the
  // subscriptions made during boot are attributed like any other.
  observeMessageBus();

  patchConnectors();
  patchBlockRendering();

  withPluginApi((api) => {
    api.renderInOutlet("above-site-header", Toolbar);
  });
}
