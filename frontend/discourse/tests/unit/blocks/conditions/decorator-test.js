import { module, test } from "qunit";
import { BlockCondition, blockCondition } from "discourse/blocks/conditions";

module("Unit | Blocks | Conditions | decorator", function () {
  module("config validation", function () {
    test("throws for missing type", function (assert) {
      assert.throws(
        () =>
          blockCondition({
            args: {},
          }),
        /`type` is required and must be a string/
      );
    });

    test("throws for non-string type", function (assert) {
      assert.throws(
        () =>
          blockCondition({
            type: 123,
            args: {},
          }),
        /`type` is required and must be a string/
      );
    });

    test("defaults to empty args object when not provided", function (assert) {
      @blockCondition({
        type: "test-no-args",
      })
      class TestCondition extends BlockCondition {
        evaluate() {
          return true;
        }
      }

      assert.deepEqual(TestCondition.argsSchema, {});
      assert.deepEqual(TestCondition.validArgKeys, []);
    });
  });

  module("sourceType validation", function () {
    test("accepts valid sourceType values", function (assert) {
      const validSourceTypes = ["none", "outletArgs", "object"];

      validSourceTypes.forEach((sourceType, index) => {
        const decorator = blockCondition({
          type: `test-source-type-${index}`,
          sourceType,
          args: {},
        });

        @decorator
        class TestCondition extends BlockCondition {
          evaluate() {
            return true;
          }
        }

        assert.strictEqual(
          TestCondition.sourceType,
          sourceType,
          `sourceType "${sourceType}" should be accepted`
        );
      });
    });

    test("throws for invalid sourceType with suggestion", function (assert) {
      assert.throws(
        () =>
          blockCondition({
            type: "test",
            sourceType: "outletarg",
            args: {},
          }),
        /Invalid `sourceType`.*"outletarg".*did you mean.*"outletArgs"/
      );
    });

    test("throws for completely invalid sourceType", function (assert) {
      assert.throws(
        () =>
          blockCondition({
            type: "test",
            sourceType: "invalid",
            args: {},
          }),
        /Invalid `sourceType`.*Valid values are: none, outletArgs, object/
      );
    });

    test("defaults to 'none' when sourceType is not provided", function (assert) {
      @blockCondition({
        type: "test-default-source",
        args: {},
      })
      class TestCondition extends BlockCondition {
        evaluate() {
          return true;
        }
      }

      assert.strictEqual(TestCondition.sourceType, "none");
    });
  });

  module("unknown config keys validation", function () {
    test("throws for unknown config key with suggestion", function (assert) {
      assert.throws(
        () =>
          blockCondition({
            type: "test",
            args: {},
            sourceType: "none",
            arg: {},
          }),
        /unknown config key.*"arg".*did you mean.*"args"/
      );
    });

    test("throws for multiple unknown config keys", function (assert) {
      assert.throws(
        () =>
          blockCondition({
            type: "test",
            args: {},
            sourceTyp: "none",
            typo: true,
          }),
        /unknown config key.*"sourceTyp".*"typo"/
      );
    });

    test("throws for typo in sourceType key", function (assert) {
      assert.throws(
        () =>
          blockCondition({
            type: "test",
            args: {},
            sourcetype: "outletArgs",
          }),
        /unknown config key.*"sourcetype".*did you mean.*"sourceType"/
      );
    });

    test("accepts only valid config keys", function (assert) {
      @blockCondition({
        type: "test-valid-keys",
        sourceType: "outletArgs",
        args: {
          foo: { type: "string" },
          bar: { type: "number" },
        },
      })
      class TestCondition extends BlockCondition {
        evaluate() {
          return true;
        }
      }

      assert.strictEqual(TestCondition.type, "test-valid-keys");
      assert.strictEqual(TestCondition.sourceType, "outletArgs");
      assert.deepEqual(TestCondition.validArgKeys, ["foo", "bar", "source"]);
    });
  });

  module("args schema validation", function () {
    test("validates arg type is valid", function (assert) {
      assert.throws(
        () =>
          blockCondition({
            type: "test",
            args: {
              myArg: { type: "invalid" },
            },
          }),
        /arg "myArg" has invalid type/
      );
    });

    test("validates arg name format", function (assert) {
      assert.throws(
        () =>
          blockCondition({
            type: "test",
            args: {
              "invalid-name": { type: "string" },
            },
          }),
        /arg name "invalid-name" is invalid/
      );
    });

    test("rejects default property for conditions", function (assert) {
      assert.throws(
        () =>
          blockCondition({
            type: "test",
            args: {
              myArg: { type: "string", default: "value" },
            },
          }),
        /disallowed property "default"/
      );
    });

    test("allows type: 'any' for accepting any value type", function (assert) {
      @blockCondition({
        type: "test-any-type",
        args: {
          anyValue: { type: "any" },
        },
      })
      class TestCondition extends BlockCondition {
        evaluate() {
          return true;
        }
      }

      assert.deepEqual(TestCondition.argsSchema, { anyValue: { type: "any" } });
    });

    test("validates enum values match declared type", function (assert) {
      assert.throws(
        () =>
          blockCondition({
            type: "test",
            args: {
              myArg: { type: "string", enum: [1, 2, 3] },
            },
          }),
        /enum contains invalid value/
      );
    });

    test("validates min/max/integer only for number type", function (assert) {
      assert.throws(
        () =>
          blockCondition({
            type: "test",
            args: {
              myArg: { type: "string", min: 0 },
            },
          }),
        /"min" is only valid for number type/
      );
    });

    test("validates minLength/maxLength for string and array types", function (assert) {
      assert.throws(
        () =>
          blockCondition({
            type: "test",
            args: {
              myArg: { type: "number", minLength: 0 },
            },
          }),
        /"minLength" is only valid for string or array/
      );
    });
  });

  module("constraints validation", function () {
    test("validates constraint types are known", function (assert) {
      assert.throws(
        () =>
          blockCondition({
            type: "test",
            args: {
              a: { type: "string" },
              b: { type: "string" },
            },
            constraints: {
              unknownConstraint: ["a", "b"],
            },
          }),
        /unknown constraint type.*"unknownConstraint"/i
      );
    });

    test("validates constraint args exist in schema", function (assert) {
      assert.throws(
        () =>
          blockCondition({
            type: "test",
            args: {
              a: { type: "string" },
            },
            constraints: {
              atLeastOne: ["a", "nonexistent"],
            },
          }),
        /references unknown arg.*"nonexistent"/
      );
    });

    test("accepts valid constraints", function (assert) {
      @blockCondition({
        type: "test-constraints",
        args: {
          a: { type: "string" },
          b: { type: "string" },
        },
        constraints: {
          atLeastOne: ["a", "b"],
        },
      })
      class TestCondition extends BlockCondition {
        evaluate() {
          return true;
        }
      }

      assert.deepEqual(TestCondition.constraints, { atLeastOne: ["a", "b"] });
    });

    test("accepts atMostOne constraint", function (assert) {
      @blockCondition({
        type: "test-at-most-one",
        args: {
          optionA: { type: "string" },
          optionB: { type: "string" },
          optionC: { type: "string" },
        },
        constraints: {
          atMostOne: ["optionA", "optionB", "optionC"],
        },
      })
      class TestCondition extends BlockCondition {
        evaluate() {
          return true;
        }
      }

      assert.deepEqual(TestCondition.constraints, {
        atMostOne: ["optionA", "optionB", "optionC"],
      });
    });
  });

  module("validate function", function () {
    test("throws when validate is not a function", function (assert) {
      assert.throws(
        () =>
          blockCondition({
            type: "test",
            args: {},
            validate: "not a function",
          }),
        /"validate" must be a function/
      );
    });

    test("accepts validate function", function (assert) {
      const validateFn = () => null;

      @blockCondition({
        type: "test-validate-fn",
        args: {
          foo: { type: "string" },
        },
        validate: validateFn,
      })
      class TestCondition extends BlockCondition {
        evaluate() {
          return true;
        }
      }

      assert.strictEqual(TestCondition.validateFn, validateFn);
    });
  });

  module("class validation", function () {
    test("throws when class does not extend BlockCondition", function (assert) {
      class NotACondition {}

      assert.throws(() => {
        blockCondition({
          type: "invalid-class",
          args: {},
        })(NotACondition);
      }, /NotACondition must extend BlockCondition/);
    });

    test("accepts class that extends BlockCondition", function (assert) {
      @blockCondition({
        type: "valid-class",
        args: {},
      })
      class ValidCondition extends BlockCondition {
        evaluate() {
          return true;
        }
      }

      assert.strictEqual(ValidCondition.type, "valid-class");
    });
  });

  module("static property assignment", function () {
    test("assigns type as static getter", function (assert) {
      @blockCondition({
        type: "static-type-test",
        args: {},
      })
      class TestCondition extends BlockCondition {
        evaluate() {
          return true;
        }
      }

      assert.strictEqual(TestCondition.type, "static-type-test");
    });

    test("assigns sourceType as static getter", function (assert) {
      @blockCondition({
        type: "static-source-test",
        sourceType: "object",
        args: {},
      })
      class TestCondition extends BlockCondition {
        evaluate() {
          return true;
        }
      }

      assert.strictEqual(TestCondition.sourceType, "object");
    });

    test("assigns argsSchema as static getter", function (assert) {
      const schema = {
        foo: { type: "string", required: true },
        bar: { type: "number", min: 0 },
      };

      @blockCondition({
        type: "static-schema-test",
        args: schema,
      })
      class TestCondition extends BlockCondition {
        evaluate() {
          return true;
        }
      }

      assert.deepEqual(TestCondition.argsSchema, schema);
    });

    test("derives validArgKeys from args schema", function (assert) {
      @blockCondition({
        type: "derived-keys-test",
        sourceType: "outletArgs",
        args: {
          foo: { type: "string" },
          bar: { type: "number" },
        },
      })
      class TestCondition extends BlockCondition {
        evaluate() {
          return true;
        }
      }

      assert.deepEqual(TestCondition.validArgKeys, ["foo", "bar", "source"]);
    });

    test("does not add source to validArgKeys when sourceType is none", function (assert) {
      @blockCondition({
        type: "no-source-key-test",
        sourceType: "none",
        args: {
          foo: { type: "string" },
        },
      })
      class TestCondition extends BlockCondition {
        evaluate() {
          return true;
        }
      }

      assert.deepEqual(TestCondition.validArgKeys, ["foo"]);
    });

    test("freezes validArgKeys array", function (assert) {
      @blockCondition({
        type: "frozen-keys-test",
        args: {
          foo: { type: "string" },
        },
      })
      class TestCondition extends BlockCondition {
        evaluate() {
          return true;
        }
      }

      assert.true(Object.isFrozen(TestCondition.validArgKeys));
    });

    test("freezes argsSchema object", function (assert) {
      @blockCondition({
        type: "frozen-schema-test",
        args: {
          foo: { type: "string" },
        },
      })
      class TestCondition extends BlockCondition {
        evaluate() {
          return true;
        }
      }

      assert.true(Object.isFrozen(TestCondition.argsSchema));
    });
  });

  module("type namespace validation", function () {
    test("accepts valid core type (simple name)", function (assert) {
      @blockCondition({
        type: "simple-type",
        args: {},
      })
      class TestCondition extends BlockCondition {
        evaluate() {
          return true;
        }
      }

      assert.strictEqual(TestCondition.type, "simple-type");
      assert.strictEqual(TestCondition.namespace, null);
      assert.strictEqual(TestCondition.namespaceType, "core");
    });

    test("accepts valid plugin type (namespace:name)", function (assert) {
      @blockCondition({
        type: "chat:unread-messages",
        args: {},
      })
      class TestCondition extends BlockCondition {
        evaluate() {
          return true;
        }
      }

      assert.strictEqual(TestCondition.type, "chat:unread-messages");
      assert.strictEqual(TestCondition.namespace, "chat");
      assert.strictEqual(TestCondition.namespaceType, "plugin");
    });

    test("accepts valid theme type (theme:namespace:name)", function (assert) {
      @blockCondition({
        type: "theme:tactile:dark-mode",
        args: {},
      })
      class TestCondition extends BlockCondition {
        evaluate() {
          return true;
        }
      }

      assert.strictEqual(TestCondition.type, "theme:tactile:dark-mode");
      assert.strictEqual(TestCondition.namespace, "theme-tactile");
      assert.strictEqual(TestCondition.namespaceType, "theme");
    });

    test("throws for uppercase in type", function (assert) {
      assert.throws(
        () =>
          blockCondition({
            type: "InvalidType",
            args: {},
          }),
        /type "InvalidType" is invalid/
      );
    });

    test("throws for underscores in type", function (assert) {
      assert.throws(
        () =>
          blockCondition({
            type: "invalid_type",
            args: {},
          }),
        /type "invalid_type" is invalid/
      );
    });

    test("throws for type exceeding max length", function (assert) {
      const longType = "a".repeat(101);

      assert.throws(
        () =>
          blockCondition({
            type: longType,
            args: {},
          }),
        /exceeds maximum length/
      );
    });

    test("throws for invalid theme format (theme:name without namespace)", function (assert) {
      assert.throws(
        () =>
          blockCondition({
            type: "theme:my-type",
            args: {},
          }),
        /type "theme:my-type" is invalid/
      );
    });

    test("allows type with numbers", function (assert) {
      @blockCondition({
        type: "type-123",
        args: {},
      })
      class TestCondition extends BlockCondition {
        evaluate() {
          return true;
        }
      }

      assert.strictEqual(TestCondition.type, "type-123");
    });
  });
});
