import { getOwner, setOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import BlockUserCondition from "discourse/blocks/conditions/user";
import { BlockError } from "discourse/lib/blocks/error";

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
        BlockError
      );
    });

    test("throws when loggedIn: false combined with moderator", function (assert) {
      assert.throws(
        () => this.condition.validate({ loggedIn: false, moderator: true }),
        BlockError
      );
    });

    test("throws when loggedIn: false combined with staff", function (assert) {
      assert.throws(
        () => this.condition.validate({ loggedIn: false, staff: true }),
        BlockError
      );
    });

    test("throws when loggedIn: false combined with minTrustLevel", function (assert) {
      assert.throws(
        () => this.condition.validate({ loggedIn: false, minTrustLevel: 2 }),
        BlockError
      );
    });

    test("throws when loggedIn: false combined with maxTrustLevel", function (assert) {
      assert.throws(
        () => this.condition.validate({ loggedIn: false, maxTrustLevel: 2 }),
        BlockError
      );
    });

    test("throws when loggedIn: false combined with groups", function (assert) {
      assert.throws(
        () =>
          this.condition.validate({ loggedIn: false, groups: ["some-group"] }),
        BlockError
      );
    });

    test("throws when minTrustLevel > maxTrustLevel", function (assert) {
      assert.throws(
        () => this.condition.validate({ minTrustLevel: 3, maxTrustLevel: 1 }),
        BlockError
      );
    });

    test("throws when minTrustLevel is negative", function (assert) {
      assert.throws(
        () => this.condition.validate({ minTrustLevel: -1 }),
        /must be a number between 0 and 4/
      );
    });

    test("throws when maxTrustLevel is negative", function (assert) {
      assert.throws(
        () => this.condition.validate({ maxTrustLevel: -1 }),
        /must be a number between 0 and 4/
      );
    });

    test("throws when minTrustLevel exceeds 4", function (assert) {
      assert.throws(
        () => this.condition.validate({ minTrustLevel: 5 }),
        /must be a number between 0 and 4/
      );
    });

    test("throws when maxTrustLevel exceeds 4", function (assert) {
      assert.throws(
        () => this.condition.validate({ maxTrustLevel: 5 }),
        /must be a number between 0 and 4/
      );
    });

    test("throws when minTrustLevel is not a number", function (assert) {
      assert.throws(
        () => this.condition.validate({ minTrustLevel: "2" }),
        /must be a number between 0 and 4/
      );
    });

    test("throws when maxTrustLevel is not a number", function (assert) {
      assert.throws(
        () => this.condition.validate({ maxTrustLevel: "3" }),
        /must be a number between 0 and 4/
      );
    });

    test("accepts boundary trust levels 0 and 4", function (assert) {
      this.condition.validate({ minTrustLevel: 0 });
      this.condition.validate({ maxTrustLevel: 4 });
      this.condition.validate({ minTrustLevel: 0, maxTrustLevel: 4 });
      assert.true(true);
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

  module("evaluate", function () {
    module("anonymous users", function () {
      test("passes with no conditions", function (assert) {
        assert.true(this.condition.evaluate({}));
      });

      test("fails with loggedIn: true", function (assert) {
        assert.false(this.condition.evaluate({ loggedIn: true }));
      });

      test("passes with loggedIn: false", function (assert) {
        assert.true(this.condition.evaluate({ loggedIn: false }));
      });

      test("fails with admin: true", function (assert) {
        assert.false(this.condition.evaluate({ admin: true }));
      });

      test("fails with moderator: true", function (assert) {
        assert.false(this.condition.evaluate({ moderator: true }));
      });

      test("fails with staff: true", function (assert) {
        assert.false(this.condition.evaluate({ staff: true }));
      });

      test("fails with minTrustLevel", function (assert) {
        assert.false(this.condition.evaluate({ minTrustLevel: 1 }));
      });

      test("fails with maxTrustLevel", function (assert) {
        assert.false(this.condition.evaluate({ maxTrustLevel: 4 }));
      });

      test("fails with groups", function (assert) {
        assert.false(this.condition.evaluate({ groups: ["some-group"] }));
      });
    });

    module("logged-in users", function (nestedHooks) {
      nestedHooks.beforeEach(function () {
        this.condition.currentUser = {
          admin: false,
          moderator: false,
          staff: false,
          trust_level: 2,
          groups: [{ name: "trust_level_2" }, { name: "beta-testers" }],
        };
      });

      test("passes with no conditions", function (assert) {
        assert.true(this.condition.evaluate({}));
      });

      test("passes with loggedIn: true", function (assert) {
        assert.true(this.condition.evaluate({ loggedIn: true }));
      });

      test("fails with loggedIn: false", function (assert) {
        assert.false(this.condition.evaluate({ loggedIn: false }));
      });

      module("admin condition", function () {
        test("fails when user is not admin", function (assert) {
          assert.false(this.condition.evaluate({ admin: true }));
        });

        test("passes when user is admin", function (assert) {
          this.condition.currentUser.admin = true;
          assert.true(this.condition.evaluate({ admin: true }));
        });
      });

      module("moderator condition", function () {
        test("fails when user is not moderator", function (assert) {
          assert.false(this.condition.evaluate({ moderator: true }));
        });

        test("passes when user is moderator", function (assert) {
          this.condition.currentUser.moderator = true;
          assert.true(this.condition.evaluate({ moderator: true }));
        });

        test("passes when user is admin (admins are moderators)", function (assert) {
          this.condition.currentUser.admin = true;
          assert.true(this.condition.evaluate({ moderator: true }));
        });
      });

      module("staff condition", function () {
        test("fails when user is not staff", function (assert) {
          assert.false(this.condition.evaluate({ staff: true }));
        });

        test("passes when user is staff", function (assert) {
          this.condition.currentUser.staff = true;
          assert.true(this.condition.evaluate({ staff: true }));
        });
      });

      module("trust level conditions", function () {
        test("passes when trust level meets minimum", function (assert) {
          assert.true(this.condition.evaluate({ minTrustLevel: 2 }));
        });

        test("passes when trust level exceeds minimum", function (assert) {
          assert.true(this.condition.evaluate({ minTrustLevel: 1 }));
        });

        test("fails when trust level is below minimum", function (assert) {
          assert.false(this.condition.evaluate({ minTrustLevel: 3 }));
        });

        test("passes when trust level meets maximum", function (assert) {
          assert.true(this.condition.evaluate({ maxTrustLevel: 2 }));
        });

        test("passes when trust level is below maximum", function (assert) {
          assert.true(this.condition.evaluate({ maxTrustLevel: 4 }));
        });

        test("fails when trust level exceeds maximum", function (assert) {
          assert.false(this.condition.evaluate({ maxTrustLevel: 1 }));
        });

        test("passes when trust level is within range", function (assert) {
          assert.true(
            this.condition.evaluate({ minTrustLevel: 1, maxTrustLevel: 3 })
          );
        });

        test("passes when trust level equals both min and max", function (assert) {
          assert.true(
            this.condition.evaluate({ minTrustLevel: 2, maxTrustLevel: 2 })
          );
        });

        test("fails when trust level is outside range", function (assert) {
          assert.false(
            this.condition.evaluate({ minTrustLevel: 3, maxTrustLevel: 4 })
          );
        });
      });

      module("group conditions", function () {
        test("passes when user is in specified group", function (assert) {
          assert.true(this.condition.evaluate({ groups: ["beta-testers"] }));
        });

        test("passes when user is in one of multiple groups (OR logic)", function (assert) {
          assert.true(
            this.condition.evaluate({
              groups: ["alpha-testers", "beta-testers"],
            })
          );
        });

        test("fails when user is not in any specified group", function (assert) {
          assert.false(
            this.condition.evaluate({ groups: ["alpha-testers", "vip"] })
          );
        });

        test("handles empty groups array", function (assert) {
          this.condition.currentUser.groups = [];
          assert.false(this.condition.evaluate({ groups: ["any-group"] }));
        });

        test("handles undefined groups", function (assert) {
          this.condition.currentUser.groups = undefined;
          assert.false(this.condition.evaluate({ groups: ["any-group"] }));
        });
      });

      module("combined conditions", function () {
        test("passes when all conditions are met", function (assert) {
          this.condition.currentUser.staff = true;
          assert.true(
            this.condition.evaluate({
              loggedIn: true,
              staff: true,
              minTrustLevel: 2,
              groups: ["beta-testers"],
            })
          );
        });

        test("fails when one condition is not met", function (assert) {
          assert.false(
            this.condition.evaluate({
              loggedIn: true,
              admin: true,
              minTrustLevel: 2,
            })
          );
        });
      });
    });
  });

  module("static type", function () {
    test("has correct type", function (assert) {
      assert.strictEqual(BlockUserCondition.type, "user");
    });
  });
});
