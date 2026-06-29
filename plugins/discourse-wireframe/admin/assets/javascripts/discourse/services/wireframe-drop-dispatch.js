// @ts-check
import Service, { service } from "@ember/service";

/**
 * The single chokepoint that turns a completed drop into a layout mutation.
 *
 * A drop's payload (`{ action, args }`) is built during dragover by the
 * drop-zone consumers and held by `WireframeDragOverlay` across the drag; at
 * drop time the overlay calls the dispatcher registered here, which routes the
 * named action to the service that performs it — block insertion / relocation
 * on the block-mutations service, and every grid placement through the grid
 * manipulator (which itself routes through `decideGridDrop`, so no drop surface
 * can place into a grid without the decider). The action table is the entire set
 * of drop-channel actions; an unknown name is a no-op that reports failure.
 *
 * It owns the registration too: the constructor hands the overlay its
 * dispatcher, so the overlay never reaches up into a higher-level service. The
 * registration is permanent for the app lifetime (the overlay holds a single
 * dispatcher slot) and the dispatcher only fires at drop time during an active
 * drag, so there is nothing to tear down. The composition root looks this
 * service up at boot so the dispatcher is in place before the first drop.
 */
export default class WireframeDropDispatchService extends Service {
  @service wireframeBlockMutations;
  @service wireframeDragOverlay;
  @service wireframeGridManipulator;

  constructor() {
    super(...arguments);
    // Hand the overlay our dispatcher so it never reaches up into a
    // higher-level service. Synchronous + returns a boolean (the
    // `completeExternalImageDrop` contract the overlay's `dispatch()` expects).
    this.wireframeDragOverlay.registerDispatcher((payload) =>
      this.run(payload)
    );
  }

  /**
   * Executes a drop dispatch payload by action name. Called by the overlay's
   * `dispatch()` at drop time.
   *
   * @param {{action: string, args: Object}} payload
   * @returns {boolean} `true` when the named action ran.
   */
  run({ action: actionName, args }) {
    const handler = {
      insertBlock: (a) => this.wireframeBlockMutations.insertBlock(a),
      moveBlock: (a) => this.wireframeBlockMutations.moveBlock(a),
      applyGridDrop: (a) => this.wireframeGridManipulator.drop(a),
      moveBlockIntoCell: (a) => this.wireframeGridManipulator.moveIntoCell(a),
      placeBlockInCell: (a) => this.wireframeGridManipulator.placeInCell(a),
    }[actionName];
    if (!handler) {
      return false;
    }
    handler(args);
    return true;
  }
}
