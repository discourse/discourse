import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import MoveMenuCoordinator from "discourse/ui-kit/d-reorderable-list/-internals/coordinators/move-menu-coordinator";

/**
 * The coordinator is unit-tested because its one race cannot be staged through
 * rendering: in production the service's close awaits FloatKit's closing
 * animation, so an earlier menu's `onClose` can land after a later menu has
 * already opened — and that animation is short-circuited under `isTesting`,
 * which is exactly why no rendering test can see the ordering.
 */
module(
  "Unit | ui-kit | DReorderableList | MoveMenuCoordinator",
  function (hooks) {
    setupTest(hooks);

    /** Builds a coordinator whose menu service records each show's onClose. */
    function buildCoordinator() {
      const closeCallbacks = [];
      const menu = {
        async show(trigger, options) {
          closeCallbacks.push(options.onClose);
          return { destroy: sinon.spy(), expanded: false, close: sinon.spy() };
        },
      };
      const handles = new Map();
      const coordinator = new MoveMenuCoordinator({
        menu,
        args: () => ({}),
        listId: () => "default",
        handleFor: (key) => {
          if (!handles.has(key)) {
            handles.set(key, document.createElement("button"));
          }
          return handles.get(key);
        },
        rowFor: () => undefined,
        siblings: () => [],
        move: () => {},
        canSpill: () => false,
        onRefusedMove: () => {},
      });
      return { coordinator, closeCallbacks };
    }

    test("rev42618 a stale menu close does not clear the open row", async function (assert) {
      const { coordinator, closeCallbacks } = buildCoordinator();

      await coordinator.openMenu("a");
      await coordinator.openMenu("b");

      // The first menu's close arriving only now, after the second menu has
      // opened, as it does in production when its closing animation resolves
      // late.
      closeCallbacks[0]();

      assert.strictEqual(
        coordinator.openKey,
        "b",
        "a close belonging to an already-replaced menu leaves the record of the currently open row alone"
      );
    });
  }
);
