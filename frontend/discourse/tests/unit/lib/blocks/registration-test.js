import Component from "@glimmer/component";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { block } from "discourse/blocks/block-outlet";
import { OPTIONAL_MISSING } from "discourse/lib/blocks/patterns";
import {
  _freezeBlockRegistry,
  _freezeOutletRegistry,
  _registerBlock,
  _registerBlockFactory,
  _registerOutlet,
  _setTestSourceIdentifier,
  getAllOutlets,
  getBlockEntry,
  getCustomOutlet,
  hasBlock,
  isBlockFactory,
  isBlockRegistryFrozen,
  isBlockResolved,
  isOutletRegistryFrozen,
  isValidOutlet,
  resetBlockRegistryForTesting,
  resolveBlock,
  resolveBlockSync,
} from "discourse/lib/blocks/registration";
import { BLOCK_OUTLETS } from "discourse/lib/registry/block-outlets";

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

      assert.true(hasBlock("test-block"));
      assert.strictEqual(getBlockEntry("test-block"), TestBlock);
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

    test("throws after registry is frozen", function (assert) {
      @block("frozen-test-block")
      class FrozenTestBlock extends Component {}

      _freezeBlockRegistry();

      assert.throws(
        () => _registerBlock(FrozenTestBlock),
        /registry was frozen/
      );
    });
  });

  module("_freezeBlockRegistry", function () {
    test("freezes the registry", function (assert) {
      assert.false(isBlockRegistryFrozen());

      _freezeBlockRegistry();

      assert.true(isBlockRegistryFrozen());
    });
  });

  module("resetBlockRegistryForTesting", function () {
    test("clears the registry and unfreezes it", function (assert) {
      @block("reset-test-block")
      class ResetTestBlock extends Component {}

      _registerBlock(ResetTestBlock);
      _freezeBlockRegistry();

      assert.true(hasBlock("reset-test-block"));
      assert.true(isBlockRegistryFrozen());

      resetBlockRegistryForTesting();

      assert.false(hasBlock("reset-test-block"));
      assert.false(isBlockRegistryFrozen());
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

      assert.true(hasBlock("lazy-block"));
      assert.true(isBlockFactory(getBlockEntry("lazy-block")));
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

    test("throws after registry is frozen", function (assert) {
      _freezeBlockRegistry();

      assert.throws(
        () => _registerBlockFactory("frozen-factory", async () => ({})),
        /registry was frozen/
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

      assert.true(hasBlock("core-block"));
      assert.strictEqual(CoreBlock.blockName, "core-block");
      assert.strictEqual(CoreBlock.blockShortName, "core-block");
      assert.strictEqual(CoreBlock.blockNamespace, null);
      assert.strictEqual(CoreBlock.blockType, "core");
    });

    test("registers plugin block (namespace:name)", function (assert) {
      @block("chat:message-widget")
      class MessageWidget extends Component {}

      _registerBlock(MessageWidget);

      assert.true(hasBlock("chat:message-widget"));
      assert.strictEqual(MessageWidget.blockName, "chat:message-widget");
      assert.strictEqual(MessageWidget.blockShortName, "message-widget");
      assert.strictEqual(MessageWidget.blockNamespace, "chat");
      assert.strictEqual(MessageWidget.blockType, "plugin");
    });

    test("registers theme block (theme:namespace:name)", function (assert) {
      @block("theme:tactile:hero-banner")
      class HeroBanner extends Component {}

      _registerBlock(HeroBanner);

      assert.true(hasBlock("theme:tactile:hero-banner"));
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

      assert.true(hasBlock("chat:lazy-widget"));
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

  module("namespace enforcement", function (nestedHooks) {
    nestedHooks.afterEach(function () {
      _setTestSourceIdentifier(undefined);
    });

    test("theme source must use theme:namespace:name format", function (assert) {
      _setTestSourceIdentifier("theme:My Theme");

      @block("unnamespaced-block")
      class UnamespacedBlock extends Component {}

      assert.throws(
        () => _registerBlock(UnamespacedBlock),
        /Theme blocks must use the "theme:namespace:block-name" format/
      );
    });

    test("theme source allows properly namespaced blocks", function (assert) {
      _setTestSourceIdentifier("theme:My Theme");

      @block("theme:mytheme:my-block")
      class NamespacedBlock extends Component {}

      _registerBlock(NamespacedBlock);

      assert.true(hasBlock("theme:mytheme:my-block"));
    });

    test("plugin source must use namespace:name format", function (assert) {
      _setTestSourceIdentifier("plugin:my-plugin");

      @block("unnamespaced-plugin-block")
      class UnamespacedPluginBlock extends Component {}

      assert.throws(
        () => _registerBlock(UnamespacedPluginBlock),
        /Plugin blocks must use the "namespace:block-name" format/
      );
    });

    test("plugin source allows properly namespaced blocks", function (assert) {
      _setTestSourceIdentifier("plugin:chat");

      @block("chat:message-widget")
      class ChatWidget extends Component {}

      _registerBlock(ChatWidget);

      assert.true(hasBlock("chat:message-widget"));
    });

    test("factory registration enforces theme namespace", function (assert) {
      _setTestSourceIdentifier("theme:My Theme");

      assert.throws(
        () => _registerBlockFactory("my-factory-block", async () => ({})),
        /Theme blocks must use the "theme:namespace:block-name" format/
      );
    });

    test("factory registration enforces plugin namespace", function (assert) {
      _setTestSourceIdentifier("plugin:my-plugin");

      assert.throws(
        () => _registerBlockFactory("my-factory-block", async () => ({})),
        /Plugin blocks must use the "namespace:block-name" format/
      );
    });

    test("core source (null) allows unnamespaced blocks", function (assert) {
      _setTestSourceIdentifier(null);

      @block("core-block")
      class CoreBlock extends Component {}

      _registerBlock(CoreBlock);

      assert.true(hasBlock("core-block"));
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

  /* Outlet Registration */

  module("_registerOutlet", function () {
    test("registers a valid core outlet", function (assert) {
      _registerOutlet("custom-outlet");

      assert.true(isValidOutlet("custom-outlet"));
      assert.deepEqual(getCustomOutlet("custom-outlet"), {
        name: "custom-outlet",
        description: undefined,
      });
    });

    test("registers outlet with description", function (assert) {
      _registerOutlet("described-outlet", {
        description: "A test outlet for descriptions",
      });

      const outlet = getCustomOutlet("described-outlet");
      assert.strictEqual(outlet.description, "A test outlet for descriptions");
    });

    test("registers plugin outlet (namespace:name)", function (assert) {
      _setTestSourceIdentifier("plugin:chat");

      _registerOutlet("chat:message-actions");

      assert.true(isValidOutlet("chat:message-actions"));
      const outlet = getCustomOutlet("chat:message-actions");
      assert.strictEqual(outlet.name, "chat:message-actions");
    });

    test("registers theme outlet (theme:namespace:name)", function (assert) {
      _setTestSourceIdentifier("theme:My Theme");

      _registerOutlet("theme:mytheme:hero-section");

      assert.true(isValidOutlet("theme:mytheme:hero-section"));
      const outlet = getCustomOutlet("theme:mytheme:hero-section");
      assert.strictEqual(outlet.name, "theme:mytheme:hero-section");
    });

    test("throws for invalid name format", function (assert) {
      assert.throws(
        () => _registerOutlet("Invalid_Name"),
        /is invalid.*Valid formats/
      );
    });

    test("throws for duplicate outlet name", function (assert) {
      _registerOutlet("dup-outlet");

      assert.throws(() => _registerOutlet("dup-outlet"), /already registered/);
    });

    test("throws for outlet name matching core outlet", function (assert) {
      const coreOutlet = BLOCK_OUTLETS[0];

      assert.throws(
        () => _registerOutlet(coreOutlet),
        /already registered as a core outlet/
      );
    });

    test("throws after registry is frozen", function (assert) {
      _freezeOutletRegistry();

      assert.throws(
        () => _registerOutlet("frozen-outlet"),
        /registry was frozen/
      );
    });
  });

  module("outlet namespace enforcement", function (nestedHooks) {
    nestedHooks.afterEach(function () {
      _setTestSourceIdentifier(undefined);
    });

    test("theme source must use theme:namespace:name format", function (assert) {
      _setTestSourceIdentifier("theme:My Theme");

      assert.throws(
        () => _registerOutlet("unnamespaced-outlet"),
        /Theme outlets must use the "theme:namespace:outlet-name" format/
      );
    });

    test("theme source allows properly namespaced outlets", function (assert) {
      _setTestSourceIdentifier("theme:My Theme");

      _registerOutlet("theme:mytheme:custom-outlet");

      assert.true(isValidOutlet("theme:mytheme:custom-outlet"));
    });

    test("plugin source must use namespace:name format", function (assert) {
      _setTestSourceIdentifier("plugin:my-plugin");

      assert.throws(
        () => _registerOutlet("unnamespaced-plugin-outlet"),
        /Plugin outlets must use the "namespace:outlet-name" format/
      );
    });

    test("plugin source allows properly namespaced outlets", function (assert) {
      _setTestSourceIdentifier("plugin:chat");

      _registerOutlet("chat:sidebar-outlet");

      assert.true(isValidOutlet("chat:sidebar-outlet"));
    });

    test("core source (null) allows unnamespaced outlets", function (assert) {
      _setTestSourceIdentifier(null);

      _registerOutlet("core-outlet");

      assert.true(isValidOutlet("core-outlet"));
    });
  });

  module("_freezeOutletRegistry", function () {
    test("freezes the outlet registry", function (assert) {
      assert.false(isOutletRegistryFrozen());

      _freezeOutletRegistry();

      assert.true(isOutletRegistryFrozen());
    });
  });

  module("getAllOutlets", function () {
    test("includes core outlets", function (assert) {
      const allOutlets = getAllOutlets();

      BLOCK_OUTLETS.forEach((coreOutlet) => {
        assert.true(
          allOutlets.includes(coreOutlet),
          `should include core outlet: ${coreOutlet}`
        );
      });
    });

    test("includes custom registered outlets", function (assert) {
      _registerOutlet("custom-test-outlet");

      const allOutlets = getAllOutlets();

      assert.true(allOutlets.includes("custom-test-outlet"));
    });

    test("returns combined list of core and custom outlets", function (assert) {
      _registerOutlet("first-custom");
      _registerOutlet("second-custom");

      const allOutlets = getAllOutlets();

      assert.strictEqual(
        allOutlets.length,
        BLOCK_OUTLETS.length + 2,
        "should have core outlets plus 2 custom"
      );
      assert.true(allOutlets.includes("first-custom"));
      assert.true(allOutlets.includes("second-custom"));
    });
  });

  module("isValidOutlet", function () {
    test("returns true for core outlets", function (assert) {
      BLOCK_OUTLETS.forEach((coreOutlet) => {
        assert.true(
          isValidOutlet(coreOutlet),
          `should validate core outlet: ${coreOutlet}`
        );
      });
    });

    test("returns true for custom registered outlets", function (assert) {
      _registerOutlet("valid-custom-outlet");

      assert.true(isValidOutlet("valid-custom-outlet"));
    });

    test("returns false for unregistered outlets", function (assert) {
      assert.false(isValidOutlet("nonexistent-outlet"));
      assert.false(isValidOutlet("random:namespaced-outlet"));
    });
  });

  module("getCustomOutlet", function () {
    test("returns outlet data for registered custom outlet", function (assert) {
      _registerOutlet("data-outlet", { description: "Test description" });

      const outlet = getCustomOutlet("data-outlet");

      assert.strictEqual(outlet.name, "data-outlet");
      assert.strictEqual(outlet.description, "Test description");
    });

    test("returns undefined for core outlets", function (assert) {
      const coreOutlet = BLOCK_OUTLETS[0];

      assert.strictEqual(getCustomOutlet(coreOutlet), undefined);
    });

    test("returns undefined for unregistered outlets", function (assert) {
      assert.strictEqual(getCustomOutlet("not-registered"), undefined);
    });
  });

  module("resetBlockRegistryForTesting clears outlets", function () {
    test("clears custom outlets and unfreezes outlet registry", function (assert) {
      _registerOutlet("reset-test-outlet");
      _freezeOutletRegistry();

      assert.true(isValidOutlet("reset-test-outlet"));
      assert.true(isOutletRegistryFrozen());

      resetBlockRegistryForTesting();

      assert.false(
        isValidOutlet("reset-test-outlet"),
        "custom outlet should be cleared"
      );
      assert.false(
        isOutletRegistryFrozen(),
        "outlet registry should be unfrozen"
      );
      assert.true(
        isValidOutlet(BLOCK_OUTLETS[0]),
        "core outlets should still be valid"
      );
    });
  });
});
