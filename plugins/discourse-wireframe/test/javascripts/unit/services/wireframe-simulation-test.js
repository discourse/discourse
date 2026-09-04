import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";

module(
  "Unit | Discourse Wireframe | service:wireframe-simulation",
  function (hooks) {
    setupTest(hooks);

    hooks.beforeEach(function () {
      this.sim = getOwner(this).lookup("service:wireframe-simulation");
    });

    hooks.afterEach(function () {
      this.sim.clear();
    });

    test("is inactive by default", function (assert) {
      assert.strictEqual(this.sim.value, null, "no slot");
      assert.false(this.sim.isSimulating);
    });

    test("setUser with a persona object activates simulation", function (assert) {
      this.sim.setUser({ trust_level: 2 });
      assert.true(this.sim.isSimulating);
      assert.strictEqual(this.sim.value.user.trust_level, 2);
    });

    test("setUser(null) simulates an anonymous viewer (still active)", function (assert) {
      this.sim.setUser(null);
      assert.true(
        this.sim.isSimulating,
        "null persona is an explicit anon sim"
      );
      assert.true("user" in this.sim.value, "the slot is present");
      assert.strictEqual(this.sim.value.user, null);
    });

    test("setUser(undefined) clears the persona slot", function (assert) {
      this.sim.setUser({ trust_level: 4 });
      this.sim.setUser(undefined);
      assert.false(this.sim.isSimulating, "the only slot was removed");
      assert.strictEqual(this.sim.value, null);
    });

    test("clearing one slot keeps a still-set sibling slot active", function (assert) {
      this.sim.setUser({ trust_level: 2 });
      this.sim.setViewport({ viewport: { sm: true }, touch: true });
      this.sim.setViewport(undefined);
      assert.true(this.sim.isSimulating, "persona-only sim is still active");
      assert.false("viewport" in this.sim.value, "viewport slot removed");
      assert.strictEqual(this.sim.value.user.trust_level, 2, "persona kept");
    });

    test("clear() resets everything to null", function (assert) {
      this.sim.setUser({ trust_level: 4 });
      this.sim.setViewport({ viewport: { sm: true }, touch: true });
      this.sim.clear();
      assert.false(this.sim.isSimulating);
      assert.strictEqual(this.sim.value, null);
    });

    test("every mutation bumps the shared layout signal", function (assert) {
      const revision = getOwner(this).lookup("service:wireframe-layout-signal");
      const before = revision.version;
      this.sim.setUser({ trust_level: 2 });
      assert.strictEqual(revision.version, before + 1, "setUser bumps");
      this.sim.setViewport({ viewport: { sm: true }, touch: true });
      assert.strictEqual(revision.version, before + 2, "setViewport bumps");
      this.sim.clear();
      assert.strictEqual(revision.version, before + 3, "clear bumps");
    });
  }
);
