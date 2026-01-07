import Component from "@glimmer/component";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { block } from "discourse/components/block-outlet";
import { OPTIONAL_MISSING } from "discourse/lib/blocks/patterns";
import {
  _lockBlockRegistry,
  _registerBlock,
  _registerBlockFactory,
  blockRegistry,
  hasBlock,
  isBlockFactory,
  isBlockRegistryLocked,
  isBlockResolved,
  resetBlockRegistryForTesting,
  resolveBlock,
  resolveBlockSync,
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
        /is invalid.*Valid formats/
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

    test("returns true after factory resolution", async function (assert) {
      @block("factory-resolved")
      class FactoryResolved extends Component {}

      _registerBlockFactory("factory-resolved", async () => FactoryResolved);

      assert.false(isBlockResolved("factory-resolved"), "Before resolution");
      await resolveBlock("factory-resolved");
      assert.true(isBlockResolved("factory-resolved"), "After resolution");
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

    test("throws if factory returns block with mismatched name", async function (assert) {
      @block("actual-name")
      class MismatchedBlock extends Component {}

      _registerBlockFactory("registered-name", async () => MismatchedBlock);

      await assert.rejects(
        resolveBlock("registered-name"),
        /registered as "registered-name" resolved to a block with blockName "actual-name"/
      );
    });

    test("throws for invalid block reference type", async function (assert) {
      await assert.rejects(
        resolveBlock(null),
        /Invalid block reference.*expected string name or @block-decorated class/
      );
    });
  });

  module("namespaced blocks", function () {
    test("registers core block (no namespace)", function (assert) {
      @block("core-block")
      class CoreBlock extends Component {}

      _registerBlock(CoreBlock);

      assert.true(blockRegistry.has("core-block"));
      assert.strictEqual(CoreBlock.blockName, "core-block");
      assert.strictEqual(CoreBlock.blockShortName, "core-block");
      assert.strictEqual(CoreBlock.blockNamespace, null);
      assert.strictEqual(CoreBlock.blockType, "core");
    });

    test("registers plugin block (namespace:name)", function (assert) {
      @block("chat:message-widget")
      class MessageWidget extends Component {}

      _registerBlock(MessageWidget);

      assert.true(blockRegistry.has("chat:message-widget"));
      assert.strictEqual(MessageWidget.blockName, "chat:message-widget");
      assert.strictEqual(MessageWidget.blockShortName, "message-widget");
      assert.strictEqual(MessageWidget.blockNamespace, "chat");
      assert.strictEqual(MessageWidget.blockType, "plugin");
    });

    test("registers theme block (theme:namespace:name)", function (assert) {
      @block("theme:tactile:hero-banner")
      class HeroBanner extends Component {}

      _registerBlock(HeroBanner);

      assert.true(blockRegistry.has("theme:tactile:hero-banner"));
      assert.strictEqual(HeroBanner.blockName, "theme:tactile:hero-banner");
      assert.strictEqual(HeroBanner.blockShortName, "hero-banner");
      assert.strictEqual(HeroBanner.blockNamespace, "tactile");
      assert.strictEqual(HeroBanner.blockType, "theme");
    });

    test("registers factory with namespaced name", function (assert) {
      _registerBlockFactory("chat:lazy-widget", async () => {
        @block("chat:lazy-widget")
        class LazyWidget extends Component {}
        return LazyWidget;
      });

      assert.true(blockRegistry.has("chat:lazy-widget"));
    });

    test("resolves factory with namespaced name", async function (assert) {
      @block("theme:test:lazy-block")
      class LazyBlock extends Component {}

      _registerBlockFactory("theme:test:lazy-block", async () => LazyBlock);

      const resolved = await resolveBlock("theme:test:lazy-block");
      assert.strictEqual(resolved, LazyBlock);
      assert.strictEqual(resolved.blockType, "theme");
    });

    test("throws for invalid namespaced format", function (assert) {
      // theme: requires namespace segment
      assert.throws(() => {
        @block("theme:invalid")
        class InvalidTheme extends Component {}
        _registerBlock(InvalidTheme);
      }, /is invalid.*Valid formats/);
    });
  });

  module("resolution tracking", function () {
    test("concurrent resolveBlock calls only invoke factory once", async function (assert) {
      @block("concurrent-block")
      class ConcurrentBlock extends Component {}

      let callCount = 0;
      _registerBlockFactory("concurrent-block", async () => {
        callCount++;
        // Add a small delay to simulate async work
        await new Promise((resolve) => setTimeout(resolve, 10));
        return ConcurrentBlock;
      });

      // Start multiple resolutions concurrently (don't await yet)
      const promise1 = resolveBlock("concurrent-block");
      const promise2 = resolveBlock("concurrent-block");
      const promise3 = resolveBlock("concurrent-block");

      // Wait for all resolutions
      const [result1, result2, result3] = await Promise.all([
        promise1,
        promise2,
        promise3,
      ]);

      // All should resolve to the same class
      assert.strictEqual(result1, ConcurrentBlock);
      assert.strictEqual(result2, ConcurrentBlock);
      assert.strictEqual(result3, ConcurrentBlock);

      // The factory should only be called once despite 3 concurrent calls
      assert.strictEqual(callCount, 1, "Factory should be called only once");
    });

    test("failed resolution is cached and not retried", async function (assert) {
      let callCount = 0;
      _registerBlockFactory("failing-block", async () => {
        callCount++;
        throw new Error("Factory failed!");
      });

      // Helper to safely resolve (catches the thrown BlockError in DEBUG mode)
      const safeResolve = async (name) => {
        try {
          return await resolveBlock(name);
        } catch {
          return undefined;
        }
      };

      // First resolution attempt should fail
      const result1 = await safeResolve("failing-block");
      assert.strictEqual(result1, undefined, "First call returns undefined");
      assert.strictEqual(callCount, 1, "Factory called once");

      // Second resolution attempt should not call factory again
      const result2 = await safeResolve("failing-block");
      assert.strictEqual(result2, undefined, "Second call returns undefined");
      assert.strictEqual(callCount, 1, "Factory still only called once");

      // Third attempt should also be cached
      const result3 = await safeResolve("failing-block");
      assert.strictEqual(result3, undefined, "Third call returns undefined");
      assert.strictEqual(callCount, 1, "Factory still only called once");
    });

    test("resetBlockRegistryForTesting clears failed resolution cache", async function (assert) {
      let callCount = 0;
      const registerFailingFactory = () => {
        _registerBlockFactory("reset-failing", async () => {
          callCount++;
          throw new Error("Factory failed!");
        });
      };

      // Helper to safely resolve (catches the thrown BlockError in DEBUG mode)
      const safeResolve = async (name) => {
        try {
          return await resolveBlock(name);
        } catch {
          return undefined;
        }
      };

      registerFailingFactory();

      // First attempt fails
      await safeResolve("reset-failing");
      assert.strictEqual(callCount, 1, "Factory called once");

      // Second attempt is cached
      await safeResolve("reset-failing");
      assert.strictEqual(callCount, 1, "Factory still called once (cached)");

      // Reset the registry
      resetBlockRegistryForTesting();

      // Re-register the factory
      registerFailingFactory();

      // Now factory should be called again
      await safeResolve("reset-failing");
      assert.strictEqual(callCount, 2, "Factory called again after reset");
    });

    test("pending resolutions are cleaned up after completion", async function (assert) {
      @block("pending-cleanup")
      class PendingCleanup extends Component {}

      _registerBlockFactory("pending-cleanup", async () => {
        await new Promise((resolve) => setTimeout(resolve, 10));
        return PendingCleanup;
      });

      // Start resolution
      const promise = resolveBlock("pending-cleanup");

      // Wait for it to complete
      await promise;

      // Start a new resolution - should create a new promise (not reuse old)
      // This verifies pending tracking was cleaned up
      const promise2 = resolveBlock("pending-cleanup");

      // But since it's now cached in resolvedFactoryCache, should resolve immediately
      const result = await promise2;
      assert.strictEqual(result, PendingCleanup);
    });
  });

  module("resolveBlockSync", function () {
    test("returns class directly for class references", function (assert) {
      @block("sync-class-ref")
      class SyncClassRef extends Component {}

      _registerBlock(SyncClassRef);

      const result = resolveBlockSync(SyncClassRef);
      assert.strictEqual(result, SyncClassRef);
    });

    test("returns class for registered block by string name", function (assert) {
      @block("sync-string-lookup")
      class SyncStringLookup extends Component {}

      _registerBlock(SyncStringLookup);

      const result = resolveBlockSync("sync-string-lookup");
      assert.strictEqual(result, SyncStringLookup);
    });

    test("returns optional missing marker for optional block not registered", function (assert) {
      const result = resolveBlockSync("nonexistent-block?");

      assert.strictEqual(result.optionalMissing, OPTIONAL_MISSING);
      assert.strictEqual(result.name, "nonexistent-block");
    });

    test("logs error and returns null for non-optional block not registered", function (assert) {
      // eslint-disable-next-line no-console
      const originalError = console.error;
      let errorLogged = false;
      // eslint-disable-next-line no-console
      console.error = () => (errorLogged = true);

      try {
        const result = resolveBlockSync("nonexistent-required");

        assert.strictEqual(result, null);
        assert.true(errorLogged, "Should log an error");
      } finally {
        // eslint-disable-next-line no-console
        console.error = originalError;
      }
    });

    test("returns null for unresolved factory", function (assert) {
      _registerBlockFactory("sync-unresolved-factory", async () => {
        @block("sync-unresolved-factory")
        class UnresolvedFactory extends Component {}
        return UnresolvedFactory;
      });

      const result = resolveBlockSync("sync-unresolved-factory");

      assert.strictEqual(
        result,
        null,
        "Should return null for pending factory"
      );
      assert.true(
        hasBlock("sync-unresolved-factory"),
        "Factory should still be registered"
      );
    });

    test("returns class for already-resolved factory", async function (assert) {
      @block("sync-resolved-factory")
      class ResolvedFactory extends Component {}

      _registerBlockFactory(
        "sync-resolved-factory",
        async () => ResolvedFactory
      );

      await resolveBlock("sync-resolved-factory");

      const result = resolveBlockSync("sync-resolved-factory");
      assert.strictEqual(result, ResolvedFactory);
    });
  });
});
