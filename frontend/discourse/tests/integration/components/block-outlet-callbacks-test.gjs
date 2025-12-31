import Component from "@glimmer/component";
import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import BlockOutlet, {
  _setBlockDebugCallback,
  _setBlockLoggingCallback,
  _setBlockOutletBoundaryCallback,
  block,
  renderBlocks,
} from "discourse/components/block-outlet";
import {
  _registerBlock,
  withTestBlockRegistration,
} from "discourse/lib/blocks/registration";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Blocks | BlockOutlet Callbacks", function (hooks) {
  setupRenderingTest(hooks);

  hooks.afterEach(function () {
    _setBlockDebugCallback(null);
    _setBlockLoggingCallback(null);
    _setBlockOutletBoundaryCallback(null);
  });

  module("_setBlockDebugCallback", function () {
    test("wraps rendered blocks with callback component", async function (assert) {
      @block("debug-wrap-block")
      class DebugWrapBlock extends Component {
        <template>
          <div class="debug-wrap-content">Content</div>
        </template>
      }

      let callbackCalled = false;
      let receivedBlockData = null;

      _setBlockDebugCallback((blockData) => {
        callbackCalled = true;
        receivedBlockData = blockData;
        return { Component: blockData.Component };
      });

      withTestBlockRegistration(() => _registerBlock(DebugWrapBlock));
      renderBlocks(
        "homepage-blocks",
        [{ block: DebugWrapBlock }],
        getOwner(this)
      );

      await render(
        <template><BlockOutlet @name="homepage-blocks" /></template>
      );

      assert.true(callbackCalled, "callback was called");
      assert.strictEqual(
        receivedBlockData.name,
        "debug-wrap-block",
        "received correct block name"
      );
      assert.true(
        receivedBlockData.conditionsPassed,
        "conditions passed is true"
      );
      assert.dom(".debug-wrap-content").exists();
    });

    test("shows ghost blocks when conditions fail", async function (assert) {
      @block("ghost-test-block")
      class GhostTestBlock extends Component {
        <template>
          <div class="ghost-content">Should not render</div>
        </template>
      }

      let ghostBlockReceived = false;

      _setBlockDebugCallback((blockData) => {
        if (!blockData.conditionsPassed) {
          ghostBlockReceived = true;
          return {
            Component: <template>
              <div class="ghost-indicator">Ghost: {{blockData.name}}</div>
            </template>,
          };
        }
        return { Component: blockData.Component };
      });

      withTestBlockRegistration(() => _registerBlock(GhostTestBlock));
      renderBlocks(
        "sidebar-blocks",
        [
          {
            block: GhostTestBlock,
            // loggedIn: false means "only for anonymous users" - fails when logged in
            conditions: { type: "user", loggedIn: false },
          },
        ],
        getOwner(this)
      );

      await render(<template><BlockOutlet @name="sidebar-blocks" /></template>);

      assert.true(ghostBlockReceived, "ghost block callback received");
      assert
        .dom(".ghost-content")
        .doesNotExist("original content not rendered");
      assert.dom(".ghost-indicator").exists("ghost indicator rendered");
    });

    test("can be cleared by setting to null", async function (assert) {
      @block("clear-callback-block")
      class ClearCallbackBlock extends Component {
        <template>
          <div class="clear-content">Content</div>
        </template>
      }

      let callCount = 0;
      _setBlockDebugCallback(() => {
        callCount++;
        return null;
      });

      _setBlockDebugCallback(null);

      withTestBlockRegistration(() => _registerBlock(ClearCallbackBlock));
      renderBlocks(
        "hero-blocks",
        [{ block: ClearCallbackBlock }],
        getOwner(this)
      );

      await render(<template><BlockOutlet @name="hero-blocks" /></template>);

      assert.strictEqual(callCount, 0, "callback not called after clearing");
      assert.dom(".clear-content").exists("block still renders");
    });
  });

  module("_setBlockLoggingCallback", function () {
    test("enables console logging when callback returns true", async function (assert) {
      @block("logging-test-block")
      class LoggingTestBlock extends Component {
        <template>
          <div class="logging-content">Content</div>
        </template>
      }

      const consoleStub = sinon.stub(console, "groupCollapsed");

      _setBlockLoggingCallback(() => true);

      withTestBlockRegistration(() => _registerBlock(LoggingTestBlock));
      renderBlocks(
        "main-outlet-blocks",
        [
          {
            block: LoggingTestBlock,
            conditions: { type: "user", loggedIn: false },
          },
        ],
        getOwner(this)
      );

      await render(
        <template><BlockOutlet @name="main-outlet-blocks" /></template>
      );

      assert.true(consoleStub.called, "console logging was enabled");
      consoleStub.restore();
    });

    test("disables logging when callback returns false", async function (assert) {
      @block("no-logging-block")
      class NoLoggingBlock extends Component {
        <template>
          <div class="no-logging-content">Content</div>
        </template>
      }

      const consoleStub = sinon.stub(console, "groupCollapsed");

      _setBlockLoggingCallback(() => false);

      withTestBlockRegistration(() => _registerBlock(NoLoggingBlock));
      renderBlocks(
        "header-blocks",
        [
          {
            block: NoLoggingBlock,
            conditions: { type: "user", loggedIn: false },
          },
        ],
        getOwner(this)
      );

      await render(<template><BlockOutlet @name="header-blocks" /></template>);

      assert.false(consoleStub.called, "console logging was not enabled");
      consoleStub.restore();
    });
  });

  module("_setBlockOutletBoundaryCallback", function () {
    test("shows outlet boundary when callback returns true", async function (assert) {
      @block("boundary-test-block")
      class BoundaryTestBlock extends Component {
        <template>
          <div class="boundary-content">Content</div>
        </template>
      }

      _setBlockOutletBoundaryCallback(() => true);

      withTestBlockRegistration(() => _registerBlock(BoundaryTestBlock));
      renderBlocks(
        "homepage-blocks",
        [{ block: BoundaryTestBlock }],
        getOwner(this)
      );

      await render(
        <template><BlockOutlet @name="homepage-blocks" /></template>
      );

      assert.dom(".block-outlet-debug").exists("debug boundary shown");
      assert.dom(".block-outlet-debug__badge").exists("badge shown");
      assert.dom(".boundary-content").exists("content still renders");
    });

    test("hides outlet boundary when callback returns false", async function (assert) {
      @block("no-boundary-block")
      class NoBoundaryBlock extends Component {
        <template>
          <div class="no-boundary-content">Content</div>
        </template>
      }

      _setBlockOutletBoundaryCallback(() => false);

      withTestBlockRegistration(() => _registerBlock(NoBoundaryBlock));
      renderBlocks(
        "sidebar-blocks",
        [{ block: NoBoundaryBlock }],
        getOwner(this)
      );

      await render(<template><BlockOutlet @name="sidebar-blocks" /></template>);

      assert
        .dom(".block-outlet-debug")
        .doesNotExist("debug boundary not shown");
      assert.dom(".no-boundary-content").exists("content renders normally");
    });

    test("can be cleared by setting to null", async function (assert) {
      @block("boundary-clear-block")
      class BoundaryClearBlock extends Component {
        <template>
          <div class="boundary-clear-content">Content</div>
        </template>
      }

      _setBlockOutletBoundaryCallback(() => true);
      _setBlockOutletBoundaryCallback(null);

      withTestBlockRegistration(() => _registerBlock(BoundaryClearBlock));
      renderBlocks(
        "hero-blocks",
        [{ block: BoundaryClearBlock }],
        getOwner(this)
      );

      await render(<template><BlockOutlet @name="hero-blocks" /></template>);

      assert
        .dom(".block-outlet-debug")
        .doesNotExist("debug boundary not shown after clearing");
    });
  });
});
