import Component from "@glimmer/component";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { block } from "discourse/components/block-outlet";
import {
  _lockBlockRegistry,
  _registerBlock,
  blockRegistry,
  isBlockRegistryLocked,
  resetBlockRegistryForTesting,
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
});
