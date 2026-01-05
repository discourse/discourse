import Component from "@glimmer/component";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { block } from "discourse/components/block-outlet";
import {
  _lockBlockRegistry,
  _registerBlock,
  _registerBlockByName,
  _registerBlockFactory,
  blockRegistry,
  hasBlock,
  isBlockFactory,
  isBlockRegistryLocked,
  isBlockResolved,
  resetBlockRegistryForTesting,
  resolveBlock,
} from "discourse/lib/blocks/registration";

module("Unit | Lib | blocks/registration", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    resetBlockRegistryForTesting();
  });

  hooks.afterEach(function () {
    resetBlockRegistryForTesting();
  });

  module("_registerBlock", function () {
    test("registers a valid block", function (assert) {
      @block("test-block")
      class TestBlock extends Component {}

      _registerBlock(TestBlock);

      assert.true(blockRegistry.has("test-block"));
      assert.strictEqual(blockRegistry.get("test-block"), TestBlock);
    });

    test("throws for class without @block decorator", function (assert) {
      // eslint-disable-next-line ember/no-empty-glimmer-component-classes
      class PlainComponent extends Component {}

      assert.throws(
        () => _registerBlock(PlainComponent),
        /must be decorated with @block/
      );
    });

    test("throws for duplicate block name", function (assert) {
      @block("duplicate-block")
      class FirstBlock extends Component {}

      @block("duplicate-block")
      class SecondBlock extends Component {}

      _registerBlock(FirstBlock);

      assert.throws(() => _registerBlock(SecondBlock), /already registered/);
    });

    test("throws after registry is locked", function (assert) {
      @block("locked-test-block")
      class LockedTestBlock extends Component {}

      _lockBlockRegistry();

      assert.throws(
        () => _registerBlock(LockedTestBlock),
        /registry is locked/
      );
    });
  });

  module("_lockBlockRegistry", function () {
    test("locks the registry", function (assert) {
      assert.false(isBlockRegistryLocked());

      _lockBlockRegistry();

      assert.true(isBlockRegistryLocked());
    });
  });

  module("resetBlockRegistryForTesting", function () {
    test("clears the registry and unlocks it", function (assert) {
      @block("reset-test-block")
      class ResetTestBlock extends Component {}

      _registerBlock(ResetTestBlock);
      _lockBlockRegistry();

      assert.true(blockRegistry.has("reset-test-block"));
      assert.true(isBlockRegistryLocked());

      resetBlockRegistryForTesting();

      assert.false(blockRegistry.has("reset-test-block"));
      assert.false(isBlockRegistryLocked());
    });
  });

  // ========================================================================
  // Dynamic Block Names (Feature 2)
  // ========================================================================

  module("_registerBlockByName", function () {
    test("registers a block with explicit name", function (assert) {
      @block("original-name")
      class MyBlock extends Component {}

      _registerBlockByName("custom-name", MyBlock);

      assert.true(blockRegistry.has("custom-name"));
      assert.strictEqual(blockRegistry.get("custom-name"), MyBlock);
    });

    test("throws for invalid name format", function (assert) {
      @block("valid-block")
      class ValidBlock extends Component {}

      assert.throws(
        () => _registerBlockByName("Invalid_Name", ValidBlock),
        /is invalid.*lowercase/
      );
    });

    test("throws for class without @block decorator", function (assert) {
      // eslint-disable-next-line ember/no-empty-glimmer-component-classes
      class PlainComponent extends Component {}

      assert.throws(
        () => _registerBlockByName("plain-block", PlainComponent),
        /must be decorated with @block/
      );
    });

    test("throws for duplicate name", function (assert) {
      @block("first-block")
      class FirstBlock extends Component {}

      @block("second-block")
      class SecondBlock extends Component {}

      _registerBlockByName("same-name", FirstBlock);

      assert.throws(
        () => _registerBlockByName("same-name", SecondBlock),
        /already registered/
      );
    });

    test("throws after registry is locked", function (assert) {
      @block("locked-block")
      class LockedBlock extends Component {}

      _lockBlockRegistry();

      assert.throws(
        () => _registerBlockByName("locked-name", LockedBlock),
        /registry is locked/
      );
    });
  });

  module("_registerBlockFactory", function () {
    test("registers a factory function", function (assert) {
      const factory = async () => {
        @block("lazy-block")
        class LazyBlock extends Component {}
        return LazyBlock;
      };

      _registerBlockFactory("lazy-block", factory);

      assert.true(blockRegistry.has("lazy-block"));
      assert.true(isBlockFactory(blockRegistry.get("lazy-block")));
    });

    test("throws for invalid name format", function (assert) {
      assert.throws(
        () => _registerBlockFactory("Invalid_Name", async () => ({})),
        /is invalid.*lowercase/
      );
    });

    test("throws for non-function factory", function (assert) {
      assert.throws(
        () => _registerBlockFactory("not-function", "not a function"),
        /must be a function/
      );
    });

    test("throws for duplicate name", function (assert) {
      _registerBlockFactory("dup-factory", async () => ({}));

      assert.throws(
        () => _registerBlockFactory("dup-factory", async () => ({})),
        /already registered/
      );
    });

    test("throws after registry is locked", function (assert) {
      _lockBlockRegistry();

      assert.throws(
        () => _registerBlockFactory("locked-factory", async () => ({})),
        /registry is locked/
      );
    });
  });

  module("isBlockFactory", function () {
    test("returns true for factory function", function (assert) {
      const factory = async () => ({});
      assert.true(isBlockFactory(factory));
    });

    test("returns false for @block decorated class", function (assert) {
      @block("decorated-class")
      class DecoratedClass extends Component {}

      assert.false(isBlockFactory(DecoratedClass));
    });

    test("returns false for non-function", function (assert) {
      assert.false(isBlockFactory("string"));
      assert.false(isBlockFactory(123));
      assert.false(isBlockFactory(null));
    });
  });

  module("hasBlock", function () {
    test("returns true for registered class by name", function (assert) {
      @block("has-block-test")
      class HasBlockTest extends Component {}

      _registerBlock(HasBlockTest);

      assert.true(hasBlock("has-block-test"));
    });

    test("returns true for registered class by reference", function (assert) {
      @block("has-block-ref")
      class HasBlockRef extends Component {}

      _registerBlock(HasBlockRef);

      assert.true(hasBlock(HasBlockRef));
    });

    test("returns true for registered factory", function (assert) {
      _registerBlockFactory("has-factory", async () => ({}));

      assert.true(hasBlock("has-factory"));
    });

    test("returns false for unregistered name", function (assert) {
      assert.false(hasBlock("unregistered-block"));
    });
  });

  module("isBlockResolved", function () {
    test("returns true for direct class registration", function (assert) {
      @block("resolved-direct")
      class ResolvedDirect extends Component {}

      _registerBlock(ResolvedDirect);

      assert.true(isBlockResolved("resolved-direct"));
    });

    test("returns true for class registered by name", function (assert) {
      @block("original-resolved")
      class OriginalResolved extends Component {}

      _registerBlockByName("custom-resolved", OriginalResolved);

      assert.true(isBlockResolved("custom-resolved"));
    });

    test("returns false for unresolved factory", function (assert) {
      _registerBlockFactory("unresolved-factory", async () => ({}));

      assert.false(isBlockResolved("unresolved-factory"));
    });

    test("returns false for unregistered name", function (assert) {
      assert.false(isBlockResolved("nonexistent"));
    });
  });

  module("resolveBlock", function () {
    test("resolves class reference directly", async function (assert) {
      @block("direct-class")
      class DirectClass extends Component {}

      _registerBlock(DirectClass);

      const resolved = await resolveBlock(DirectClass);
      assert.strictEqual(resolved, DirectClass);
    });

    test("resolves string name to registered class", async function (assert) {
      @block("string-lookup")
      class StringLookup extends Component {}

      _registerBlock(StringLookup);

      const resolved = await resolveBlock("string-lookup");
      assert.strictEqual(resolved, StringLookup);
    });

    test("resolves factory and caches result", async function (assert) {
      @block("factory-resolve")
      class FactoryResolve extends Component {}

      let callCount = 0;
      _registerBlockFactory("factory-resolve", async () => {
        callCount++;
        return FactoryResolve;
      });

      const first = await resolveBlock("factory-resolve");
      const second = await resolveBlock("factory-resolve");

      assert.strictEqual(first, FactoryResolve);
      assert.strictEqual(second, FactoryResolve);
      assert.strictEqual(callCount, 1, "Factory called only once");
    });

    test("handles default export from factory", async function (assert) {
      @block("default-export")
      class DefaultExport extends Component {}

      _registerBlockFactory("default-export", async () => ({
        default: DefaultExport,
      }));

      const resolved = await resolveBlock("default-export");
      assert.strictEqual(resolved, DefaultExport);
    });

    test("updates isBlockResolved after factory resolution", async function (assert) {
      @block("resolve-updates")
      class ResolveUpdates extends Component {}

      _registerBlockFactory("resolve-updates", async () => ResolveUpdates);

      assert.false(isBlockResolved("resolve-updates"), "Before resolution");

      await resolveBlock("resolve-updates");

      assert.true(isBlockResolved("resolve-updates"), "After resolution");
    });

    test("throws for unregistered block name", async function (assert) {
      await assert.rejects(resolveBlock("nonexistent"), /not registered/);
    });

    test("throws if factory returns non-block class", async function (assert) {
      // eslint-disable-next-line ember/no-empty-glimmer-component-classes
      class NotABlock extends Component {}

      _registerBlockFactory("not-a-block", async () => NotABlock);

      await assert.rejects(
        resolveBlock("not-a-block"),
        /did not return a valid @block-decorated class/
      );
    });

    test("throws for invalid block reference type", async function (assert) {
      await assert.rejects(
        resolveBlock(null),
        /Invalid block reference.*expected string name or @block-decorated class/
      );
    });
  });
});
