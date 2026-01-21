import { getOwner, setOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import BlockUserCondition from "discourse/blocks/conditions/user";
import { validateConditions } from "discourse/lib/blocks/validation/conditions";

module("Unit | Blocks | Condition | user", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.condition = new BlockUserCondition();
    setOwner(this.condition, getOwner(this));

    // Helper to validate via infrastructure
    this.validateCondition = (args) => {
      const conditionTypes = new Map([["user", this.condition]]);

      try {
        validateConditions({ type: "user", ...args }, conditionTypes);
        return null;
      } catch (error) {
        return error;
      }
    };
  });

  module("validate (through infrastructure)", function () {
    test("returns error when loggedIn: false combined with admin", function (assert) {
      const error = this.validateCondition({ loggedIn: false, admin: true });
      assert.true(error?.message.includes("loggedIn: false"));
    });

    test("returns error when loggedIn: false combined with moderator", function (assert) {
      const error = this.validateCondition({
        loggedIn: false,
        moderator: true,
      });
      assert.true(error?.message.includes("loggedIn: false"));
    });

    test("returns error when loggedIn: false combined with staff", function (assert) {
      const error = this.validateCondition({ loggedIn: false, staff: true });
      assert.true(error?.message.includes("loggedIn: false"));
    });

    test("returns error when loggedIn: false combined with minTrustLevel", function (assert) {
      const error = this.validateCondition({
        loggedIn: false,
        minTrustLevel: 2,
      });
      assert.true(error?.message.includes("loggedIn: false"));
    });

    test("returns error when loggedIn: false combined with maxTrustLevel", function (assert) {
      const error = this.validateCondition({
        loggedIn: false,
        maxTrustLevel: 2,
      });
      assert.true(error?.message.includes("loggedIn: false"));
    });

    test("returns error when loggedIn: false combined with groups", function (assert) {
      const error = this.validateCondition({
        loggedIn: false,
        groups: ["some-group"],
      });
      assert.true(error?.message.includes("loggedIn: false"));
    });

    test("returns error when minTrustLevel > maxTrustLevel", function (assert) {
      const error = this.validateCondition({
        minTrustLevel: 3,
        maxTrustLevel: 1,
      });
      assert.true(error?.message.includes("cannot be greater than"));
    });

    test("returns error when minTrustLevel is negative", function (assert) {
      const error = this.validateCondition({ minTrustLevel: -1 });
      assert.true(error?.message.includes("must be at least 0"));
    });

    test("returns error when maxTrustLevel is negative", function (assert) {
      const error = this.validateCondition({ maxTrustLevel: -1 });
      assert.true(error?.message.includes("must be at least 0"));
    });

    test("returns error when minTrustLevel exceeds 4", function (assert) {
      const error = this.validateCondition({ minTrustLevel: 5 });
      assert.true(error?.message.includes("must be at most 4"));
    });

    test("returns error when maxTrustLevel exceeds 4", function (assert) {
      const error = this.validateCondition({ maxTrustLevel: 5 });
      assert.true(error?.message.includes("must be at most 4"));
    });

    test("returns error when minTrustLevel is not a number", function (assert) {
      const error = this.validateCondition({ minTrustLevel: "2" });
      assert.true(error?.message.includes("must be a number"));
    });

    test("returns error when maxTrustLevel is not a number", function (assert) {
      const error = this.validateCondition({ maxTrustLevel: "3" });
      assert.true(error?.message.includes("must be a number"));
    });

    test("accepts boundary trust levels 0 and 4", function (assert) {
      assert.strictEqual(this.validateCondition({ minTrustLevel: 0 }), null);
      assert.strictEqual(this.validateCondition({ maxTrustLevel: 4 }), null);
      assert.strictEqual(
        this.validateCondition({ minTrustLevel: 0, maxTrustLevel: 4 }),
        null
      );
    });

    test("returns error when loggedIn is not a boolean", function (assert) {
      const error = this.validateCondition({ loggedIn: "true" });
      assert.true(error?.message.includes("must be a boolean"));
    });

    test("returns error when admin is not a boolean", function (assert) {
      const error = this.validateCondition({ admin: 1 });
      assert.true(error?.message.includes("must be a boolean"));
    });

    test("returns error when moderator is not a boolean", function (assert) {
      const error = this.validateCondition({ moderator: "yes" });
      assert.true(error?.message.includes("must be a boolean"));
    });

    test("returns error when staff is not a boolean", function (assert) {
      const error = this.validateCondition({ staff: 0 });
      assert.true(error?.message.includes("must be a boolean"));
    });

    test("returns error when groups is not an array", function (assert) {
      const error = this.validateCondition({ groups: "beta-testers" });
      assert.true(error?.message.includes("must be an array"));
    });

    test("returns error when groups contains non-string values", function (assert) {
      const error = this.validateCondition({ groups: ["valid", 123] });
      assert.true(error?.message.includes("must be a string"));
    });

    test("passes valid configurations", function (assert) {
      assert.strictEqual(this.validateCondition({ loggedIn: true }), null);
      assert.strictEqual(this.validateCondition({ loggedIn: false }), null);
      assert.strictEqual(this.validateCondition({ admin: true }), null);
      assert.strictEqual(this.validateCondition({ moderator: true }), null);
      assert.strictEqual(this.validateCondition({ staff: true }), null);
      assert.strictEqual(this.validateCondition({ minTrustLevel: 2 }), null);
      assert.strictEqual(this.validateCondition({ maxTrustLevel: 3 }), null);
      assert.strictEqual(
        this.validateCondition({ minTrustLevel: 1, maxTrustLevel: 3 }),
        null
      );
      assert.strictEqual(
        this.validateCondition({ minTrustLevel: 2, maxTrustLevel: 2 }),
        null
      );
      assert.strictEqual(
        this.validateCondition({ groups: ["test-group"] }),
        null
      );
      assert.strictEqual(
        this.validateCondition({ loggedIn: true, admin: true }),
        null
      );
      assert.strictEqual(
        this.validateCondition({
          minTrustLevel: 2,
          groups: ["beta"],
          staff: true,
        }),
        null
      );
    });
  });

  module("evaluate", function () {
    module("anonymous users", function () {
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

        test("admin: false is a no-op (passes for any user)", function (assert) {
          assert.true(
            this.condition.evaluate({ admin: false }),
            "non-admin user passes"
          );

          this.condition.currentUser.admin = true;
          assert.true(
            this.condition.evaluate({ admin: false }),
            "admin user also passes"
          );
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

        test("moderator: false is a no-op (passes for any user)", function (assert) {
          assert.true(
            this.condition.evaluate({ moderator: false }),
            "non-moderator user passes"
          );

          this.condition.currentUser.moderator = true;
          assert.true(
            this.condition.evaluate({ moderator: false }),
            "moderator user also passes"
          );
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

        test("staff: false is a no-op (passes for any user)", function (assert) {
          assert.true(
            this.condition.evaluate({ staff: false }),
            "non-staff user passes"
          );

          this.condition.currentUser.staff = true;
          assert.true(
            this.condition.evaluate({ staff: false }),
            "staff user also passes"
          );
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

  module("source parameter", function () {
    test("has sourceType of outletArgs", function (assert) {
      assert.strictEqual(BlockUserCondition.sourceType, "outletArgs");
    });

    test("validate passes with valid source format", function (assert) {
      assert.strictEqual(
        this.validateCondition({ source: "@outletArgs.user", admin: true }),
        null
      );
    });

    test("validate returns error with invalid source format", function (assert) {
      const error = this.validateCondition({ source: "user", admin: true });
      assert.notStrictEqual(error, null, "returns an error");
      assert.true(
        error.message.includes("must be in format"),
        "error message mentions format"
      );
    });

    test("validate returns error when no args specified (atLeastOne constraint)", function (assert) {
      const error = this.validateCondition({});
      assert.notStrictEqual(error, null, "returns an error");
      assert.true(
        error.message.includes("at least one of"),
        "error message mentions atLeastOne"
      );
    });

    test("uses user from source when provided", function (assert) {
      const outletUser = {
        admin: true,
        moderator: true,
        staff: true,
        trust_level: 4,
      };

      const context = { outletArgs: { customUser: outletUser } };
      const result = this.condition.evaluate(
        { source: "@outletArgs.customUser", admin: true },
        context
      );

      assert.true(result);
    });

    test("does NOT fall back to currentUser when source resolves to undefined", function (assert) {
      this.condition.currentUser = {
        admin: true,
        trust_level: 2,
      };

      const context = { outletArgs: {} };
      // Source is provided but resolves to undefined - should use undefined, not currentUser
      const result = this.condition.evaluate(
        { source: "@outletArgs.user", admin: true },
        context
      );

      // No user found at source path, so admin check fails
      assert.false(result);
    });

    test("checks source user properties correctly", function (assert) {
      const outletUser = {
        admin: false,
        moderator: true,
        staff: true,
        trust_level: 3,
      };

      const context = { outletArgs: { topicAuthor: outletUser } };

      // Should fail admin check on source user
      assert.false(
        this.condition.evaluate(
          { source: "@outletArgs.topicAuthor", admin: true },
          context
        )
      );

      // Should pass moderator check on source user
      assert.true(
        this.condition.evaluate(
          { source: "@outletArgs.topicAuthor", moderator: true },
          context
        )
      );

      // Should pass trust level check on source user
      assert.true(
        this.condition.evaluate(
          { source: "@outletArgs.topicAuthor", minTrustLevel: 2 },
          context
        )
      );
    });

    test("handles nested source paths", function (assert) {
      const topicCreator = {
        admin: true,
        trust_level: 4,
      };

      const context = { outletArgs: { topic: { creator: topicCreator } } };
      const result = this.condition.evaluate(
        { source: "@outletArgs.topic.creator", admin: true },
        context
      );

      assert.true(result);
    });

    module("nested source path error handling", function () {
      test("handles null intermediate value in source path", function (assert) {
        const context = { outletArgs: { topic: null } };
        const result = this.condition.evaluate(
          { source: "@outletArgs.topic.creator", admin: true },
          context
        );
        assert.false(result);
      });

      test("handles undefined intermediate value in source path", function (assert) {
        const context = { outletArgs: { topic: { creator: undefined } } };
        const result = this.condition.evaluate(
          { source: "@outletArgs.topic.creator", admin: true },
          context
        );
        assert.false(result);
      });

      test("handles missing root property in source path", function (assert) {
        const context = { outletArgs: {} };
        const result = this.condition.evaluate(
          { source: "@outletArgs.topic.creator", admin: true },
          context
        );
        assert.false(result);
      });

      test("handles deeply nested source path with null at various levels", function (assert) {
        // null at first level
        let context = { outletArgs: { a: null } };
        assert.false(
          this.condition.evaluate(
            { source: "@outletArgs.a.b.c", admin: true },
            context
          ),
          "null at first level"
        );

        // null at second level
        context = { outletArgs: { a: { b: null } } };
        assert.false(
          this.condition.evaluate(
            { source: "@outletArgs.a.b.c", admin: true },
            context
          ),
          "null at second level"
        );
      });

      test("handles source resolving to non-user object gracefully", function (assert) {
        const context = { outletArgs: { topic: { creator: "not-a-user" } } };
        const result = this.condition.evaluate(
          { source: "@outletArgs.topic.creator", admin: true },
          context
        );
        assert.false(result);
      });

      test("handles missing outletArgs in context", function (assert) {
        const result = this.condition.evaluate(
          { source: "@outletArgs.user", admin: true },
          {}
        );
        assert.false(result);
      });

      test("handles null outletArgs in context", function (assert) {
        const result = this.condition.evaluate(
          { source: "@outletArgs.user", admin: true },
          { outletArgs: null }
        );
        assert.false(result);
      });
    });

    module("loggedIn comparison with currentUser", function (nestedHooks) {
      nestedHooks.beforeEach(function () {
        this.condition.currentUser = {
          id: 42,
          admin: false,
          trust_level: 2,
        };
      });

      test("loggedIn: true passes when source user IS currentUser", function (assert) {
        const context = { outletArgs: { postUser: { id: 42 } } };
        assert.true(
          this.condition.evaluate(
            { source: "@outletArgs.postUser", loggedIn: true },
            context
          )
        );
      });

      test("loggedIn: true fails when source user is NOT currentUser", function (assert) {
        const context = { outletArgs: { postUser: { id: 99 } } };
        assert.false(
          this.condition.evaluate(
            { source: "@outletArgs.postUser", loggedIn: true },
            context
          )
        );
      });

      test("loggedIn: true fails when source user is undefined", function (assert) {
        const context = { outletArgs: {} };
        assert.false(
          this.condition.evaluate(
            { source: "@outletArgs.postUser", loggedIn: true },
            context
          )
        );
      });

      test("loggedIn: false fails when source user IS currentUser", function (assert) {
        const context = { outletArgs: { postUser: { id: 42 } } };
        assert.false(
          this.condition.evaluate(
            { source: "@outletArgs.postUser", loggedIn: false },
            context
          )
        );
      });

      test("loggedIn: false passes when source user is NOT currentUser", function (assert) {
        const context = { outletArgs: { postUser: { id: 99 } } };
        assert.true(
          this.condition.evaluate(
            { source: "@outletArgs.postUser", loggedIn: false },
            context
          )
        );
      });

      test("loggedIn: false passes when source user is undefined", function (assert) {
        const context = { outletArgs: {} };
        assert.true(
          this.condition.evaluate(
            { source: "@outletArgs.postUser", loggedIn: false },
            context
          )
        );
      });

      test("loggedIn: true fails when currentUser is null (anon)", function (assert) {
        this.condition.currentUser = null;
        const context = { outletArgs: { postUser: { id: 99 } } };
        assert.false(
          this.condition.evaluate(
            { source: "@outletArgs.postUser", loggedIn: true },
            context
          )
        );
      });

      test("loggedIn: false passes when currentUser is null (anon)", function (assert) {
        this.condition.currentUser = null;
        const context = { outletArgs: { postUser: { id: 99 } } };
        assert.true(
          this.condition.evaluate(
            { source: "@outletArgs.postUser", loggedIn: false },
            context
          )
        );
      });

      test("compares by reference when users have no id", function (assert) {
        const sharedUser = { username: "test" };
        this.condition.currentUser = sharedUser;
        const context = { outletArgs: { postUser: sharedUser } };

        assert.true(
          this.condition.evaluate(
            { source: "@outletArgs.postUser", loggedIn: true },
            context
          ),
          "same reference passes"
        );

        const differentUser = { username: "test" };
        const context2 = { outletArgs: { postUser: differentUser } };
        assert.false(
          this.condition.evaluate(
            { source: "@outletArgs.postUser", loggedIn: true },
            context2
          ),
          "different reference fails even with same properties"
        );
      });
    });
  });

  module("static type", function () {
    test("has correct type", function (assert) {
      assert.strictEqual(BlockUserCondition.type, "user");
    });
  });
});
