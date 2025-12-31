import { getOwner, setOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { BlockConditionValidationError } from "discourse/blocks/conditions";
import BlockUserCondition from "discourse/blocks/conditions/user";

module("Unit | Blocks | Condition | user", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.condition = new BlockUserCondition();
    setOwner(this.condition, getOwner(this));
  });

  module("validate", function () {
    test("throws when loggedIn: false combined with admin", function (assert) {
      assert.throws(
        () => this.condition.validate({ loggedIn: false, admin: true }),
        BlockConditionValidationError
      );
    });

    test("throws when loggedIn: false combined with moderator", function (assert) {
      assert.throws(
        () => this.condition.validate({ loggedIn: false, moderator: true }),
        BlockConditionValidationError
      );
    });

    test("throws when loggedIn: false combined with staff", function (assert) {
      assert.throws(
        () => this.condition.validate({ loggedIn: false, staff: true }),
        BlockConditionValidationError
      );
    });

    test("throws when loggedIn: false combined with minTrustLevel", function (assert) {
      assert.throws(
        () => this.condition.validate({ loggedIn: false, minTrustLevel: 2 }),
        BlockConditionValidationError
      );
    });

    test("throws when loggedIn: false combined with maxTrustLevel", function (assert) {
      assert.throws(
        () => this.condition.validate({ loggedIn: false, maxTrustLevel: 2 }),
        BlockConditionValidationError
      );
    });

    test("throws when loggedIn: false combined with groups", function (assert) {
      assert.throws(
        () =>
          this.condition.validate({ loggedIn: false, groups: ["some-group"] }),
        BlockConditionValidationError
      );
    });

    test("throws when minTrustLevel > maxTrustLevel", function (assert) {
      assert.throws(
        () => this.condition.validate({ minTrustLevel: 3, maxTrustLevel: 1 }),
        BlockConditionValidationError
      );
    });

    test("passes valid configurations", function (assert) {
      this.condition.validate({ loggedIn: true });
      this.condition.validate({ loggedIn: false });
      this.condition.validate({ admin: true });
      this.condition.validate({ moderator: true });
      this.condition.validate({ staff: true });
      this.condition.validate({ minTrustLevel: 2 });
      this.condition.validate({ maxTrustLevel: 3 });
      this.condition.validate({ minTrustLevel: 1, maxTrustLevel: 3 });
      this.condition.validate({ minTrustLevel: 2, maxTrustLevel: 2 });
      this.condition.validate({ groups: ["test-group"] });
      this.condition.validate({ loggedIn: true, admin: true });
      this.condition.validate({
        minTrustLevel: 2,
        groups: ["beta"],
        staff: true,
      });
      assert.true(true, "all valid configurations passed");
    });
  });

  module("static type", function () {
    test("has correct type", function (assert) {
      assert.strictEqual(BlockUserCondition.type, "user");
    });
  });
});
