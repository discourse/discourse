import { module, test } from "qunit";
import { computeTier } from "discourse/plugins/discourse-wireframe/discourse/lib/toolbar-fit-tier";

// The fit decision is a pure function of three measured widths, so it can be
// table-tested without a DOM. `naturalFull` here is 100, `naturalCompact` 40;
// the decision requires 1px of slack (EPSILON) before a tier may win.
module(
  "Unit | Discourse Wireframe | lib:toolbar-fit-tier computeTier",
  function () {
    test("plenty of room → full", function (assert) {
      assert.strictEqual(computeTier(500, 100, 40), "full");
      assert.strictEqual(
        computeTier(101, 100, 40),
        "full",
        "exactly one px of slack past the full width still fits"
      );
    });

    test("between compact and full → narrow", function (assert) {
      assert.strictEqual(computeTier(80, 100, 40), "narrow");
      assert.strictEqual(
        computeTier(100, 100, 40),
        "narrow",
        "sitting exactly on the full width is not enough slack, so it folds"
      );
      assert.strictEqual(
        computeTier(41, 100, 40),
        "narrow",
        "one px of slack past the compact width keeps the handle + hamburger"
      );
    });

    test("too tight even for the hamburger → narrower", function (assert) {
      assert.strictEqual(computeTier(40, 100, 40), "narrower");
      assert.strictEqual(computeTier(0, 100, 40), "narrower");
    });

    test("the decision is stable — re-feeding a tier's own width does not flip it", function (assert) {
      // The collapsed inline row is measured off-tier, so the natural widths
      // never change with the chosen tier: re-deciding at the same widths must
      // return the same tier (no oscillation at a boundary).
      const full = 100;
      const compact = 40;
      for (const avail of [500, 101, 100, 80, 41, 40, 0]) {
        assert.strictEqual(
          computeTier(avail, full, compact),
          computeTier(avail, full, compact),
          `tier at avail=${avail} is deterministic`
        );
      }
    });
  }
);
