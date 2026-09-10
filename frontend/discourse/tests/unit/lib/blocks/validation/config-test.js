import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { RESERVED_ARG_NAMES } from "discourse/lib/blocks/-internals/validation/args";
import {
  VALID_ENTRY_KEYS,
  validateEntryKeys,
  validateEntryTypes,
} from "discourse/lib/blocks/-internals/validation/layout";

module("Unit | Blocks | validation/layout", function (hooks) {
  setupTest(hooks);

  module("containerArgs in entry", function () {
    test("containerArgs is a valid entry key", function (assert) {
      assert.true(
        VALID_ENTRY_KEYS.includes("containerArgs"),
        "containerArgs is in VALID_ENTRY_KEYS"
      );
    });

    test("containerArgs is a reserved arg name", function (assert) {
      assert.true(
        RESERVED_ARG_NAMES.includes("containerArgs"),
        "containerArgs is in RESERVED_ARG_NAMES"
      );
    });

    test("validateEntryKeys accepts containerArgs", function (assert) {
      const entry = {
        block: "test-block",
        containerArgs: { name: "test" },
      };

      // Should not throw
      validateEntryKeys(entry);
      assert.true(true, "containerArgs accepted as valid entry key");
    });

    test("validateEntryTypes accepts containerArgs as object", function (assert) {
      const entry = {
        containerArgs: { name: "test" },
      };

      // Should not throw
      validateEntryTypes(entry);
      assert.true(true, "containerArgs as object accepted");
    });

    test("validateEntryTypes rejects containerArgs as array", function (assert) {
      const entry = {
        containerArgs: ["invalid"],
      };

      assert.throws(
        () => validateEntryTypes(entry),
        /"containerArgs" must be an object, got array/,
        "containerArgs as array rejected"
      );
    });

    test("validateEntryTypes rejects containerArgs as string", function (assert) {
      const entry = {
        containerArgs: "invalid",
      };

      assert.throws(
        () => validateEntryTypes(entry),
        /"containerArgs" must be an object, got string/,
        "containerArgs as string rejected"
      );
    });
  });

  module("overrides in entry", function () {
    test("overrides is a valid entry key", function (assert) {
      assert.true(
        VALID_ENTRY_KEYS.includes("overrides"),
        "overrides is in VALID_ENTRY_KEYS"
      );
    });

    test("validateEntryKeys accepts overrides", function (assert) {
      const entry = {
        block: "test-block",
        overrides: { title: { text: "Hello" } },
      };

      // Should not throw
      validateEntryKeys(entry);
      assert.true(true, "overrides accepted as valid entry key");
    });

    test("validateEntryTypes accepts overrides as object", function (assert) {
      const entry = {
        overrides: { title: { text: "Hello" } },
      };

      // Should not throw
      validateEntryTypes(entry);
      assert.true(true, "overrides as object accepted");
    });

    test("validateEntryTypes rejects overrides as array", function (assert) {
      const entry = {
        overrides: ["invalid"],
      };

      assert.throws(
        () => validateEntryTypes(entry),
        /"overrides" must be an object, got array/,
        "overrides as array rejected"
      );
    });
  });
});
