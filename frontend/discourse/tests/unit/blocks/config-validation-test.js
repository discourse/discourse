import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import {
  RESERVED_ARG_NAMES,
  VALID_CONFIG_KEYS,
  validateConfigKeys,
  validateConfigTypes,
} from "discourse/lib/blocks/config-validation";

module("Unit | Blocks | config-validation", function (hooks) {
  setupTest(hooks);

  module("containerArgs in config", function () {
    test("containerArgs is a valid config key", function (assert) {
      assert.true(
        VALID_CONFIG_KEYS.includes("containerArgs"),
        "containerArgs is in VALID_CONFIG_KEYS"
      );
    });

    test("containerArgs is a reserved arg name", function (assert) {
      assert.true(
        RESERVED_ARG_NAMES.includes("containerArgs"),
        "containerArgs is in RESERVED_ARG_NAMES"
      );
    });

    test("validateConfigKeys accepts containerArgs", function (assert) {
      const config = {
        block: "test-block",
        containerArgs: { name: "test" },
      };

      // Should not throw
      validateConfigKeys(config);
      assert.true(true, "containerArgs accepted as valid config key");
    });

    test("validateConfigTypes accepts containerArgs as object", function (assert) {
      const config = {
        containerArgs: { name: "test" },
      };

      // Should not throw
      validateConfigTypes(config);
      assert.true(true, "containerArgs as object accepted");
    });

    test("validateConfigTypes rejects containerArgs as array", function (assert) {
      const config = {
        containerArgs: ["invalid"],
      };

      assert.throws(
        () => validateConfigTypes(config),
        /"containerArgs" must be an object, got array/,
        "containerArgs as array rejected"
      );
    });

    test("validateConfigTypes rejects containerArgs as string", function (assert) {
      const config = {
        containerArgs: "invalid",
      };

      assert.throws(
        () => validateConfigTypes(config),
        /"containerArgs" must be an object, got string/,
        "containerArgs as string rejected"
      );
    });
  });
});
