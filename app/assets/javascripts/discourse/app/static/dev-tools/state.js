import { tracked } from "@glimmer/tracking";

class DevToolsState {
  @tracked pluginOutletDebug = false;
}

const state = new DevToolsState();
Object.preventExtensions(state);

export default state;
