import Component from "@glimmer/component";
import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import {
  BlockCondition,
  BlockConditionValidationError,
} from "discourse/blocks/conditions";
import { block } from "discourse/components/block-outlet";
import {
  _registerBlock,
  withTestBlockRegistration,
} from "discourse/lib/blocks/registration";

module("Unit | Service | blocks", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.blocks = getOwner(this).lookup("service:blocks");
  });

  module("block registry", function () {
    test("hasBlock returns true for registered blocks", function (assert) {
      @block("registry-test-block")
      class RegistryTestBlock extends Component {}

      withTestBlockRegistration(() => {
        _registerBlock(RegistryTestBlock);
      });

      assert.true(this.blocks.hasBlock("registry-test-block"));
    });

    test("hasBlock returns false for unregistered blocks", function (assert) {
      assert.false(this.blocks.hasBlock("nonexistent-block"));
    });

    test("getBlock returns registered block class", function (assert) {
      @block("get-block-test")
      class GetBlockTest extends Component {}

      withTestBlockRegistration(() => {
        _registerBlock(GetBlockTest);
      });

      const result = this.blocks.getBlock("get-block-test");
      assert.strictEqual(result.blockName, "get-block-test");
    });

    test("getBlock returns undefined for unregistered blocks", function (assert) {
      assert.strictEqual(this.blocks.getBlock("nonexistent"), undefined);
    });

    test("listBlocks returns all registered blocks", function (assert) {
      @block("list-block-a")
      class ListBlockA extends Component {}

      @block("list-block-b")
      class ListBlockB extends Component {}

      withTestBlockRegistration(() => {
        _registerBlock(ListBlockA);
        _registerBlock(ListBlockB);
      });

      const blocks = this.blocks.listBlocks();
      const names = blocks.map((b) => b.blockName);

      assert.true(names.includes("list-block-a"));
      assert.true(names.includes("list-block-b"));
    });

    test("listBlocksWithMetadata returns blocks with metadata", function (assert) {
      @block("metadata-list-block", {
        description: "A test block with metadata",
        args: {
          title: { type: "string", required: true },
        },
      })
      class MetadataListBlock extends Component {}

      withTestBlockRegistration(() => {
        _registerBlock(MetadataListBlock);
      });

      const blocksWithMeta = this.blocks.listBlocksWithMetadata();
      const found = blocksWithMeta.find(
        (b) => b.name === "metadata-list-block"
      );

      assert.true(!!found, "block found in list");
      assert.strictEqual(
        found.metadata.description,
        "A test block with metadata"
      );
      assert.deepEqual(found.metadata.args, {
        title: { type: "string", required: true },
      });
    });
  });

  module("built-in conditions", function () {
    test("registers built-in condition types", function (assert) {
      assert.true(this.blocks.hasConditionType("route"));
      assert.true(this.blocks.hasConditionType("user"));
      assert.true(this.blocks.hasConditionType("setting"));
      assert.true(this.blocks.hasConditionType("viewport"));
    });

    test("getRegisteredConditionTypes returns all built-in types", function (assert) {
      const types = this.blocks.getRegisteredConditionTypes();
      assert.true(types.includes("route"));
      assert.true(types.includes("user"));
      assert.true(types.includes("setting"));
      assert.true(types.includes("viewport"));
    });
  });

  module("registerConditionType", function () {
    test("registers a custom condition type", function (assert) {
      class BlockTestCondition extends BlockCondition {
        static type = "test-custom";

        evaluate() {
          return true;
        }
      }

      this.blocks.registerConditionType(BlockTestCondition);
      assert.true(this.blocks.hasConditionType("test-custom"));
    });

    test("throws if class does not extend BlockCondition", function (assert) {
      class NotACondition {
        static type = "not-a-condition";
      }

      assert.throws(
        () => this.blocks.registerConditionType(NotACondition),
        /must extend BlockCondition/
      );
    });

    test("throws if class does not define static type", function (assert) {
      class BlockNoTypeCondition extends BlockCondition {
        evaluate() {
          return true;
        }
      }

      assert.throws(
        () => this.blocks.registerConditionType(BlockNoTypeCondition),
        /must define a static 'type' property/
      );
    });

    test("throws if type is already registered", function (assert) {
      class BlockDuplicateCondition extends BlockCondition {
        static type = "route";

        evaluate() {
          return true;
        }
      }

      assert.throws(
        () => this.blocks.registerConditionType(BlockDuplicateCondition),
        /already registered/
      );
    });
  });

  module("validate", function () {
    test("passes for null/undefined conditions", function (assert) {
      assert.strictEqual(this.blocks.validate(null), undefined);
      assert.strictEqual(this.blocks.validate(undefined), undefined);
    });

    test("throws for missing type", function (assert) {
      assert.throws(
        () => this.blocks.validate({ foo: "bar" }),
        /missing "type" property/
      );
    });

    test("throws for unknown type", function (assert) {
      assert.throws(
        () => this.blocks.validate({ type: "unknown-type" }),
        /Unknown block condition type/
      );
    });

    test("validates array of conditions (AND)", function (assert) {
      assert.throws(
        () =>
          this.blocks.validate([
            { type: "user", loggedIn: true },
            { type: "unknown" },
          ]),
        /Unknown block condition type/
      );
    });

    test("validates 'any' combinator (OR)", function (assert) {
      assert.throws(
        () => this.blocks.validate({ any: "not-an-array" }),
        /"any" must be an array of conditions/
      );

      assert.throws(
        () =>
          this.blocks.validate({
            any: [{ type: "user" }, { type: "unknown" }],
          }),
        /Unknown block condition type/
      );
    });

    test("validates 'not' combinator", function (assert) {
      assert.throws(
        () => this.blocks.validate({ not: [{ type: "user" }] }),
        /"not" must be a single condition object/
      );

      assert.throws(
        () => this.blocks.validate({ not: { type: "unknown" } }),
        /Unknown block condition type/
      );
    });
  });

  module("evaluate", function () {
    test("returns true for null/undefined conditions", function (assert) {
      assert.true(this.blocks.evaluate(null));
      assert.true(this.blocks.evaluate(undefined));
    });

    test("returns false for unknown type", function (assert) {
      assert.false(this.blocks.evaluate({ type: "unknown-type" }));
    });

    test("evaluates array of conditions with AND logic", function (assert) {
      class BlockAlwaysTrueCondition extends BlockCondition {
        static type = "always-true";

        evaluate() {
          return true;
        }
      }

      class BlockAlwaysFalseCondition extends BlockCondition {
        static type = "always-false";

        evaluate() {
          return false;
        }
      }

      this.blocks.registerConditionType(BlockAlwaysTrueCondition);
      this.blocks.registerConditionType(BlockAlwaysFalseCondition);

      assert.true(
        this.blocks.evaluate([{ type: "always-true" }, { type: "always-true" }])
      );

      assert.false(
        this.blocks.evaluate([
          { type: "always-true" },
          { type: "always-false" },
        ])
      );
    });

    test("evaluates 'any' combinator with OR logic", function (assert) {
      class BlockAlwaysTrueCondition2 extends BlockCondition {
        static type = "always-true-2";

        evaluate() {
          return true;
        }
      }

      class BlockAlwaysFalseCondition2 extends BlockCondition {
        static type = "always-false-2";

        evaluate() {
          return false;
        }
      }

      this.blocks.registerConditionType(BlockAlwaysTrueCondition2);
      this.blocks.registerConditionType(BlockAlwaysFalseCondition2);

      assert.true(
        this.blocks.evaluate({
          any: [{ type: "always-false-2" }, { type: "always-true-2" }],
        })
      );

      assert.false(
        this.blocks.evaluate({
          any: [{ type: "always-false-2" }, { type: "always-false-2" }],
        })
      );
    });

    test("evaluates 'not' combinator", function (assert) {
      class BlockAlwaysTrueCondition3 extends BlockCondition {
        static type = "always-true-3";

        evaluate() {
          return true;
        }
      }

      class BlockAlwaysFalseCondition3 extends BlockCondition {
        static type = "always-false-3";

        evaluate() {
          return false;
        }
      }

      this.blocks.registerConditionType(BlockAlwaysTrueCondition3);
      this.blocks.registerConditionType(BlockAlwaysFalseCondition3);

      assert.false(this.blocks.evaluate({ not: { type: "always-true-3" } }));
      assert.true(this.blocks.evaluate({ not: { type: "always-false-3" } }));
    });

    test("passes args to condition evaluate method", function (assert) {
      let receivedArgs;

      class BlockArgCapturingCondition extends BlockCondition {
        static type = "arg-capturing";

        evaluate(args) {
          receivedArgs = args;
          return true;
        }
      }

      this.blocks.registerConditionType(BlockArgCapturingCondition);
      this.blocks.evaluate({ type: "arg-capturing", foo: "bar", baz: 123 });

      assert.deepEqual(receivedArgs, { foo: "bar", baz: 123 });
    });
  });

  module("condition service injection", function () {
    test("conditions can inject services", function (assert) {
      let injectedSiteSettings;

      class BlockServiceInjectionCondition extends BlockCondition {
        static type = "service-injection-test";

        evaluate() {
          injectedSiteSettings = this.siteSettings;
          return true;
        }
      }

      // Manually inject service since we can't use decorator in test
      Object.defineProperty(
        BlockServiceInjectionCondition.prototype,
        "siteSettings",
        {
          get() {
            return getOwner(this).lookup("service:site-settings");
          },
        }
      );

      this.blocks.registerConditionType(BlockServiceInjectionCondition);
      this.blocks.evaluate({ type: "service-injection-test" });

      assert.true(!!injectedSiteSettings, "siteSettings was injected");
      assert.strictEqual(typeof injectedSiteSettings.title, "string");
    });
  });
});

module("Unit | Conditions | BlockConditionValidationError", function () {
  test("has correct name property", function (assert) {
    const error = new BlockConditionValidationError("test message");
    assert.strictEqual(error.name, "BlockConditionValidationError");
    assert.strictEqual(error.message, "test message");
  });
});
