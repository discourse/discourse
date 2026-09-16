import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";

// `wireframe-drop-dispatch` is the single chokepoint that turns a completed drop
// into a layout mutation: the overlay holds a `{ action, args }` payload across
// the drag and calls the dispatcher this service registers at drop time. `run`
// routes each action name to the service that performs it; an unknown name is a
// no-op that reports failure. The constructor self-registers with the overlay.
module(
  "Unit | Discourse Wireframe | service:wireframe-drop-dispatch",
  function (hooks) {
    setupTest(hooks);

    hooks.beforeEach(function () {
      const owner = getOwner(this);
      this.calls = [];
      const record = (name) => (args) => this.calls.push({ name, args });

      // Capture the dispatcher the service hands the overlay so the overlay→run
      // wiring can be proven without building a full overlay drag state.
      this.registered = null;
      const stubs = [
        [
          "service:wireframe-block-mutations",
          {
            insertBlock: record("insertBlock"),
            moveBlock: record("moveBlock"),
          },
        ],
        [
          "service:wireframe-grid-placement",
          {
            drop: record("drop"),
            moveIntoCell: record("moveIntoCell"),
            placeInCell: record("placeInCell"),
          },
        ],
        [
          "service:wireframe-drag-overlay",
          { registerDispatcher: (fn) => (this.registered = fn) },
        ],
      ];
      for (const [id, stub] of stubs) {
        owner.unregister(id);
        owner.register(id, stub, { instantiate: false });
      }

      // Re-instantiate so the constructor injects the stubs above (the
      // composition root may have booted the real service already).
      owner.unregister("service:wireframe-drop-dispatch");
      this.dispatch = owner.lookup("service:wireframe-drop-dispatch");
    });

    test("each action routes to its owning service with the args", function (assert) {
      const cases = [
        { action: "insertBlock", target: "insertBlock" },
        { action: "moveBlock", target: "moveBlock" },
        { action: "applyGridDrop", target: "drop" },
        { action: "moveBlockIntoCell", target: "moveIntoCell" },
        { action: "placeBlockInCell", target: "placeInCell" },
      ];
      for (const { action, target } of cases) {
        const args = { tag: action };
        assert.true(this.dispatch.run({ action, args }), `${action} ran`);
        const last = this.calls.at(-1);
        assert.strictEqual(last.name, target, `${action} routed to ${target}`);
        assert.strictEqual(last.args, args, `${action} forwarded its args`);
      }
    });

    test("an unknown action is a no-op that reports failure", function (assert) {
      assert.false(this.dispatch.run({ action: "nope", args: {} }));
      assert.strictEqual(this.calls.length, 0, "no handler ran");
    });

    test("the constructor registers its dispatcher with the overlay", function (assert) {
      assert.strictEqual(
        typeof this.registered,
        "function",
        "a dispatcher was handed to the overlay"
      );

      const args = { tag: "viaOverlay" };
      assert.true(this.registered({ action: "insertBlock", args }));
      assert.deepEqual(this.calls.at(-1), { name: "insertBlock", args });
    });
  }
);
