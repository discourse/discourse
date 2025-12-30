import { tracked } from "@glimmer/tracking";

class DevToolsState {
  @tracked pluginOutletDebug = false;
  @tracked blockConditionDebug = false;
}

const state = new DevToolsState();
Object.preventExtensions(state);

// Expose globally for cross-bundle access (e.g., from Blocks service)
if (typeof window !== "undefined") {
  window.__DEV_TOOLS_STATE__ = state;
}

export default state;
