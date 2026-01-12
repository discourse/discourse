import Component from "@glimmer/component";
import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { BlockCondition, blockCondition } from "discourse/blocks/conditions";
import { block } from "discourse/components/block-outlet";
import {
  _registerBlock,
  _registerConditionType,
  withTestBlockRegistration,
  withTestConditionRegistration,
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

  module("_registerConditionType", function () {
    test("registers a custom condition type", function (assert) {
      @blockCondition({
        type: "test-custom",
        validArgKeys: [],
      })
      class BlockTestCondition extends BlockCondition {
        evaluate() {
          return true;
        }
      }

      withTestConditionRegistration(() => {
        _registerConditionType(BlockTestCondition);
      });
      assert.true(this.blocks.hasConditionType("test-custom"));
    });

    test("throws if class does not use decorator", function (assert) {
      class NotDecoratedCondition extends BlockCondition {
        static type = "not-decorated";

        evaluate() {
          return true;
        }
      }

      assert.throws(
        () =>
          withTestConditionRegistration(() => {
            _registerConditionType(NotDecoratedCondition);
          }),
        /must use the @blockCondition decorator/
      );
    });

    test("throws if type is already registered", function (assert) {
      @blockCondition({
        type: "route",
        validArgKeys: [],
      })
      class BlockDuplicateCondition extends BlockCondition {
        evaluate() {
          return true;
        }
      }

      assert.throws(
        () =>
          withTestConditionRegistration(() => {
            _registerConditionType(BlockDuplicateCondition);
          }),
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
        /Unknown condition type/
      );
    });

    test("validates array of conditions (AND)", function (assert) {
      assert.throws(
        () =>
          this.blocks.validate([
            { type: "user", loggedIn: true },
            { type: "unknown" },
          ]),
        /Unknown condition type/
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
        /Unknown condition type/
      );
    });

    test("validates 'not' combinator", function (assert) {
      assert.throws(
        () => this.blocks.validate({ not: [{ type: "user" }] }),
        /"not" must be a single condition object/
      );

      assert.throws(
        () => this.blocks.validate({ not: { type: "unknown" } }),
        /Unknown condition type/
      );
    });

    test("throws for extra keys alongside 'any' combinator", function (assert) {
      assert.throws(
        () =>
          this.blocks.validate({
            any: [{ type: "user" }],
            extraKey: "value",
          }),
        /extra keys.*extraKey.*Only "any" is allowed/
      );

      assert.throws(
        () =>
          this.blocks.validate({
            any: [{ type: "user" }],
            type: "user",
            loggedIn: true,
          }),
        /extra keys.*type.*loggedIn.*Only "any" is allowed/
      );
    });

    test("throws for extra keys alongside 'not' combinator", function (assert) {
      assert.throws(
        () =>
          this.blocks.validate({
            not: { type: "user" },
            extraKey: "value",
          }),
        /extra keys.*extraKey.*Only "not" is allowed/
      );

      assert.throws(
        () =>
          this.blocks.validate({
            not: { type: "user" },
            type: "user",
          }),
        /extra keys.*type.*Only "not" is allowed/
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
      @blockCondition({
        type: "always-true",
        validArgKeys: [],
      })
      class BlockAlwaysTrueCondition extends BlockCondition {
        evaluate() {
          return true;
        }
      }

      @blockCondition({
        type: "always-false",
        validArgKeys: [],
      })
      class BlockAlwaysFalseCondition extends BlockCondition {
        evaluate() {
          return false;
        }
      }

      withTestConditionRegistration(() => {
        _registerConditionType(BlockAlwaysTrueCondition);
        _registerConditionType(BlockAlwaysFalseCondition);
      });

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
      @blockCondition({
        type: "always-true-2",
        validArgKeys: [],
      })
      class BlockAlwaysTrueCondition2 extends BlockCondition {
        evaluate() {
          return true;
        }
      }

      @blockCondition({
        type: "always-false-2",
        validArgKeys: [],
      })
      class BlockAlwaysFalseCondition2 extends BlockCondition {
        evaluate() {
          return false;
        }
      }

      withTestConditionRegistration(() => {
        _registerConditionType(BlockAlwaysTrueCondition2);
        _registerConditionType(BlockAlwaysFalseCondition2);
      });

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
      @blockCondition({
        type: "always-true-3",
        validArgKeys: [],
      })
      class BlockAlwaysTrueCondition3 extends BlockCondition {
        evaluate() {
          return true;
        }
      }

      @blockCondition({
        type: "always-false-3",
        validArgKeys: [],
      })
      class BlockAlwaysFalseCondition3 extends BlockCondition {
        evaluate() {
          return false;
        }
      }

      withTestConditionRegistration(() => {
        _registerConditionType(BlockAlwaysTrueCondition3);
        _registerConditionType(BlockAlwaysFalseCondition3);
      });

      assert.false(this.blocks.evaluate({ not: { type: "always-true-3" } }));
      assert.true(this.blocks.evaluate({ not: { type: "always-false-3" } }));
    });

    test("passes args to condition evaluate method", function (assert) {
      let receivedArgs;

      @blockCondition({
        type: "arg-capturing",
        validArgKeys: ["foo", "baz"],
      })
      class BlockArgCapturingCondition extends BlockCondition {
        evaluate(args) {
          receivedArgs = args;
          return true;
        }
      }

      withTestConditionRegistration(() => {
        _registerConditionType(BlockArgCapturingCondition);
      });
      this.blocks.evaluate({ type: "arg-capturing", foo: "bar", baz: 123 });

      assert.deepEqual(receivedArgs, { foo: "bar", baz: 123 });
    });

    test("returns true for empty AND array (vacuous truth)", function (assert) {
      assert.true(this.blocks.evaluate([]));
    });

    test("returns false for empty OR array (any)", function (assert) {
      assert.false(this.blocks.evaluate({ any: [] }));
    });

    test("evaluates nested combinators (NOT within OR within AND)", function (assert) {
      @blockCondition({
        type: "nested-true",
        validArgKeys: [],
      })
      class BlockNestedTrue extends BlockCondition {
        evaluate() {
          return true;
        }
      }

      @blockCondition({
        type: "nested-false",
        validArgKeys: [],
      })
      class BlockNestedFalse extends BlockCondition {
        evaluate() {
          return false;
        }
      }

      withTestConditionRegistration(() => {
        _registerConditionType(BlockNestedTrue);
        _registerConditionType(BlockNestedFalse);
      });

      // AND with OR inside: [{ any: [false, true] }] => true
      assert.true(
        this.blocks.evaluate([
          {
            any: [{ type: "nested-false" }, { type: "nested-true" }],
          },
        ])
      );

      // AND with NOT inside OR: [{ any: [{ not: { type: "nested-true" } }] }] => false
      assert.false(
        this.blocks.evaluate([
          {
            any: [{ not: { type: "nested-true" } }],
          },
        ])
      );

      // Complex: AND[ OR[NOT(false), false], true ] => AND[ OR[true, false], true ] => AND[true, true] => true
      assert.true(
        this.blocks.evaluate([
          {
            any: [{ not: { type: "nested-false" } }, { type: "nested-false" }],
          },
          { type: "nested-true" },
        ])
      );
    });

    test("passes outletArgs to condition evaluate context", function (assert) {
      let receivedContext;

      @blockCondition({
        type: "context-capturing",
        validArgKeys: [],
      })
      class BlockContextCapturing extends BlockCondition {
        evaluate(args, context) {
          receivedContext = context;
          return true;
        }
      }

      withTestConditionRegistration(() => {
        _registerConditionType(BlockContextCapturing);
      });

      const outletArgs = { topic: { id: 123 }, user: { admin: true } };
      this.blocks.evaluate({ type: "context-capturing" }, { outletArgs });

      assert.deepEqual(receivedContext.outletArgs, outletArgs);
    });

    test("passes outletArgs through NOT combinator", function (assert) {
      let receivedOutletArgs;

      @blockCondition({
        type: "not-outlet-args",
        validArgKeys: [],
      })
      class BlockNotOutletArgs extends BlockCondition {
        evaluate(args, context) {
          receivedOutletArgs = context?.outletArgs;
          return false;
        }
      }

      withTestConditionRegistration(() => {
        _registerConditionType(BlockNotOutletArgs);
      });

      const outletArgs = { topic: { closed: true } };
      this.blocks.evaluate(
        { not: { type: "not-outlet-args" } },
        { outletArgs }
      );

      assert.deepEqual(
        receivedOutletArgs,
        outletArgs,
        "outletArgs should be passed through NOT combinator"
      );
    });

    test("passes outletArgs through nested AND/OR/NOT combinators", function (assert) {
      let callCount = 0;
      const receivedOutletArgs = [];

      @blockCondition({
        type: "deep-outlet-args",
        validArgKeys: [],
      })
      class BlockDeepOutletArgs extends BlockCondition {
        evaluate(args, context) {
          callCount++;
          receivedOutletArgs.push(context?.outletArgs);
          return true;
        }
      }

      withTestConditionRegistration(() => {
        _registerConditionType(BlockDeepOutletArgs);
      });

      const outletArgs = { data: "test-value" };

      // Complex nested: AND[ OR[ NOT(condition) ] ]
      this.blocks.evaluate(
        [
          {
            any: [{ not: { type: "deep-outlet-args" } }],
          },
        ],
        { outletArgs }
      );

      assert.strictEqual(callCount, 1, "condition should be called once");
      assert.deepEqual(
        receivedOutletArgs[0],
        outletArgs,
        "outletArgs should be passed through all combinator levels"
      );
    });
  });

  module("condition service injection", function () {
    test("conditions can inject services", function (assert) {
      let injectedSiteSettings;

      @blockCondition({
        type: "service-injection-test",
        validArgKeys: [],
      })
      class BlockServiceInjectionCondition extends BlockCondition {
        evaluate() {
          injectedSiteSettings = this.siteSettings;
          return true;
        }
      }

      // Manually inject service since we can't use @service decorator in test
      Object.defineProperty(
        BlockServiceInjectionCondition.prototype,
        "siteSettings",
        {
          get() {
            return getOwner(this).lookup("service:site-settings");
          },
        }
      );

      withTestConditionRegistration(() => {
        _registerConditionType(BlockServiceInjectionCondition);
      });
      this.blocks.evaluate({ type: "service-injection-test" });

      assert.true(!!injectedSiteSettings, "siteSettings was injected");
      assert.strictEqual(typeof injectedSiteSettings.title, "string");
    });
  });
});
