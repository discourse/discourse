import { tracked } from "@glimmer/tracking";

class DevToolsState {
  @tracked pluginOutletDebug = false;

  /**
   * Enable console logging of block condition evaluations.
   *
   * @type {boolean}
   */
  @tracked blockDebug = false;

  /**
   * Enable visual overlay showing block boundaries and info.
   *
   * @type {boolean}
   */
  @tracked blockVisualOverlay = false;

  /**
   * Show block outlet boundaries even when empty.
   *
   * @type {boolean}
   */
  @tracked blockOutletBoundaries = false;
}

const state = new DevToolsState();
Object.preventExtensions(state);

export default state;
