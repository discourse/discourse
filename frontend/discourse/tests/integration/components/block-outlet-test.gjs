import Component from "@glimmer/component";
import { getOwner } from "@ember/owner";
import { render, setupOnerror } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import BlockGroup from "discourse/blocks/block-group";
import BlockOutlet, {
  _getOutletLayouts,
  block,
  renderBlocks,
} from "discourse/components/block-outlet";
import { DEBUG_CALLBACK, debugHooks } from "discourse/lib/blocks/debug-hooks";
import {
  _registerBlock,
  _registerBlockFactory,
  withTestBlockRegistration,
} from "discourse/lib/blocks/registration";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Blocks | BlockOutlet", function (hooks) {
  setupRenderingTest(hooks);

  hooks.afterEach(function () {
    setupOnerror();
    debugHooks.setCallback(DEBUG_CALLBACK.VISUAL_OVERLAY, null);
    debugHooks.setCallback(DEBUG_CALLBACK.BLOCK_DEBUG, null);
    debugHooks.setCallback(DEBUG_CALLBACK.BLOCK_LOGGING, null);
    debugHooks.setCallback(DEBUG_CALLBACK.OUTLET_BOUNDARY, null);
    debugHooks.setCallback(DEBUG_CALLBACK.START_GROUP, null);
  });

  module("basic rendering", function () {
    test("renders nothing when no blocks registered for outlet", async function (assert) {
      await render(<template><BlockOutlet @name="hero-blocks" /></template>);

      assert.dom(".hero-blocks").doesNotExist();
    });

    test("renders blocks when registered for outlet", async function (assert) {
      @block("render-test-block")
      class RenderTestBlock extends Component {
        <template>
          <div class="render-test-content">Test Content</div>
        </template>
      }

      withTestBlockRegistration(() => _registerBlock(RenderTestBlock));
      renderBlocks("homepage-blocks", [{ block: RenderTestBlock }]);

      await render(
        <template><BlockOutlet @name="homepage-blocks" /></template>
      );

      assert.dom(".homepage-blocks").exists();
      assert.dom(".render-test-content").hasText("Test Content");
    });

    test("renders correct BEM class structure", async function (assert) {
      @block("bem-test-block")
      class BemTestBlock extends Component {
        <template>
          <span>BEM Test</span>
        </template>
      }

      withTestBlockRegistration(() => _registerBlock(BemTestBlock));
      renderBlocks("sidebar-blocks", [{ block: BemTestBlock }]);

      await render(<template><BlockOutlet @name="sidebar-blocks" /></template>);

      assert.dom(".sidebar-blocks").exists();
      assert.dom(".sidebar-blocks__container").exists();
      assert.dom(".sidebar-blocks__layout").exists();
    });

    test("wraps non-container blocks with block classes", async function (assert) {
      @block("wrapped-block")
      class WrappedBlock extends Component {
        <template>
          <span>Wrapped</span>
        </template>
      }

      withTestBlockRegistration(() => _registerBlock(WrappedBlock));
      renderBlocks("main-outlet-blocks", [
        { block: WrappedBlock, classNames: "custom-class" },
      ]);

      await render(
        <template><BlockOutlet @name="main-outlet-blocks" /></template>
      );

      assert.dom(".main-outlet-blocks__block").exists();
      assert.dom(".block-wrapped-block").exists();
      assert.dom(".custom-class").exists();
    });

    test("passes args to block components", async function (assert) {
      @block("args-test-block", {
        args: { title: { type: "string" }, count: { type: "number" } },
      })
      class ArgsTestBlock extends Component {
        <template>
          <div class="args-test">
            <span class="title">{{@title}}</span>
            <span class="count">{{@count}}</span>
          </div>
        </template>
      }

      withTestBlockRegistration(() => _registerBlock(ArgsTestBlock));
      renderBlocks("header-blocks", [
        { block: ArgsTestBlock, args: { title: "Hello", count: 42 } },
      ]);

      await render(<template><BlockOutlet @name="header-blocks" /></template>);

      assert.dom(".args-test .title").hasText("Hello");
      assert.dom(".args-test .count").hasText("42");
    });

    test("applies default values from metadata when args not provided", async function (assert) {
      @block("defaults-test-block", {
        args: {
          title: { type: "string", default: "Default Title" },
          count: { type: "number", default: 10 },
          enabled: { type: "boolean", default: true },
        },
      })
      class DefaultsTestBlock extends Component {
        <template>
          <div class="defaults-test">
            <span class="title">{{@title}}</span>
            <span class="count">{{@count}}</span>
            <span class="enabled">{{if @enabled "yes" "no"}}</span>
          </div>
        </template>
      }

      withTestBlockRegistration(() => _registerBlock(DefaultsTestBlock));
      renderBlocks("main-outlet-blocks", [{ block: DefaultsTestBlock }]);

      await render(
        <template><BlockOutlet @name="main-outlet-blocks" /></template>
      );

      assert.dom(".defaults-test .title").hasText("Default Title");
      assert.dom(".defaults-test .count").hasText("10");
      assert.dom(".defaults-test .enabled").hasText("yes");
    });

    test("provided args override default values", async function (assert) {
      @block("override-defaults-block", {
        args: {
          title: { type: "string", default: "Default Title" },
          count: { type: "number", default: 10 },
        },
      })
      class OverrideDefaultsBlock extends Component {
        <template>
          <div class="override-test">
            <span class="title">{{@title}}</span>
            <span class="count">{{@count}}</span>
          </div>
        </template>
      }

      withTestBlockRegistration(() => _registerBlock(OverrideDefaultsBlock));
      renderBlocks("hero-blocks", [
        {
          block: OverrideDefaultsBlock,
          args: { title: "Custom Title", count: 99 },
        },
      ]);

      await render(<template><BlockOutlet @name="hero-blocks" /></template>);

      assert.dom(".override-test .title").hasText("Custom Title");
      assert.dom(".override-test .count").hasText("99");
    });

    test("partial args use defaults for missing values", async function (assert) {
      @block("partial-defaults-block", {
        args: {
          title: { type: "string", default: "Default Title" },
          subtitle: { type: "string", default: "Default Subtitle" },
        },
      })
      class PartialDefaultsBlock extends Component {
        <template>
          <div class="partial-test">
            <span class="title">{{@title}}</span>
            <span class="subtitle">{{@subtitle}}</span>
          </div>
        </template>
      }

      withTestBlockRegistration(() => _registerBlock(PartialDefaultsBlock));
      renderBlocks("sidebar-blocks", [
        {
          block: PartialDefaultsBlock,
          args: { title: "Custom Title" },
        },
      ]);

      await render(<template><BlockOutlet @name="sidebar-blocks" /></template>);

      assert.dom(".partial-test .title").hasText("Custom Title");
      assert.dom(".partial-test .subtitle").hasText("Default Subtitle");
    });
  });

  module("named blocks", function () {
    test(":before block yields hasBlocks boolean (false when no blocks)", async function (assert) {
      await render(
        <template>
          <BlockOutlet @name="hero-blocks">
            <:before as |hasBlocks|>
              <div class="before-block">
                {{#if hasBlocks}}
                  <span class="has-blocks">Has Blocks</span>
                {{else}}
                  <span class="no-blocks">No Blocks</span>
                {{/if}}
              </div>
            </:before>
          </BlockOutlet>
        </template>
      );

      assert.dom(".before-block").exists();
      assert.dom(".no-blocks").exists();
      assert.dom(".has-blocks").doesNotExist();
    });

    test(":after block yields hasBlocks boolean", async function (assert) {
      await render(
        <template>
          <BlockOutlet @name="hero-blocks">
            <:after as |hasBlocks|>
              <div class="after-block">
                {{#if hasBlocks}}
                  <span class="has-blocks">Has Blocks</span>
                {{else}}
                  <span class="no-blocks">No Blocks</span>
                {{/if}}
              </div>
            </:after>
          </BlockOutlet>
        </template>
      );

      assert.dom(".after-block").exists();
      assert.dom(".no-blocks").exists();
      assert.dom(".has-blocks").doesNotExist();
    });
  });

  module("authorization and security", function () {
    test("throws when @block component used directly in template", async function (assert) {
      @block("direct-usage-block")
      class DirectUsageBlock extends Component {
        <template>
          <span>Should not render</span>
        </template>
      }

      let errorThrown = null;
      setupOnerror((error) => {
        errorThrown = error;
      });

      await render(<template><DirectUsageBlock /></template>);

      assert.true(
        errorThrown?.message?.includes("cannot be used directly in templates"),
        "throws authorization error"
      );
    });
  });

  module("debug callbacks", function () {
    test("debugHooks.setCallback(BLOCK_DEBUG) wraps rendered blocks", async function (assert) {
      @block("debug-wrap-block")
      class DebugWrapBlock extends Component {
        <template>
          <div class="debug-wrap-content">Content</div>
        </template>
      }

      let callbackCalled = false;
      let receivedBlockData = null;

      debugHooks.setCallback(DEBUG_CALLBACK.BLOCK_DEBUG, (blockData) => {
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

    test("debugHooks.setCallback(BLOCK_DEBUG) shows ghost blocks when conditions fail", async function (assert) {
      @block("ghost-test-block")
      class GhostTestBlock extends Component {
        <template>
          <div class="ghost-content">Should not render</div>
        </template>
      }

      let ghostBlockReceived = false;

      debugHooks.setCallback(DEBUG_CALLBACK.VISUAL_OVERLAY, () => true);
      debugHooks.setCallback(DEBUG_CALLBACK.BLOCK_DEBUG, (blockData) => {
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

    test("debugHooks.setCallback(BLOCK_DEBUG) can be cleared by setting to null", async function (assert) {
      @block("clear-callback-block")
      class ClearCallbackBlock extends Component {
        <template>
          <div class="clear-content">Content</div>
        </template>
      }

      let callCount = 0;
      debugHooks.setCallback(DEBUG_CALLBACK.BLOCK_DEBUG, () => {
        callCount++;
        return null;
      });

      debugHooks.setCallback(DEBUG_CALLBACK.BLOCK_DEBUG, null);

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

    test("debugHooks.setCallback(BLOCK_DEBUG) receives correct hierarchy for direct children", async function (assert) {
      @block("direct-child-block")
      class DirectChildBlock extends Component {
        <template>
          <div class="direct-child">Direct Child</div>
        </template>
      }

      const receivedContexts = [];

      debugHooks.setCallback(
        DEBUG_CALLBACK.BLOCK_DEBUG,
        (blockData, context) => {
          receivedContexts.push({
            name: blockData.name,
            outletName: context.outletName,
          });
          return { Component: blockData.Component };
        }
      );

      withTestBlockRegistration(() => _registerBlock(DirectChildBlock));
      renderBlocks(
        "homepage-blocks",
        [{ block: DirectChildBlock }],
        getOwner(this)
      );

      await render(
        <template><BlockOutlet @name="homepage-blocks" /></template>
      );

      assert.strictEqual(receivedContexts.length, 1, "callback called once");
      assert.strictEqual(
        receivedContexts[0].name,
        "direct-child-block",
        "received correct block name"
      );
      assert.strictEqual(
        receivedContexts[0].outletName,
        "homepage-blocks",
        "direct child receives outlet name as hierarchy"
      );
    });

    test("debugHooks.setCallback(BLOCK_DEBUG) receives correct hierarchy for children of container blocks", async function (assert) {
      @block("nested-child-block")
      class NestedChildBlock extends Component {
        <template>
          <div class="nested-child">Nested Child</div>
        </template>
      }

      const receivedContexts = [];

      debugHooks.setCallback(
        DEBUG_CALLBACK.BLOCK_DEBUG,
        (blockData, context) => {
          receivedContexts.push({
            name: blockData.name,
            outletName: context?.outletName,
          });
          return { Component: blockData.Component };
        }
      );

      withTestBlockRegistration(() => _registerBlock(NestedChildBlock));
      renderBlocks(
        "sidebar-blocks",
        [
          {
            block: BlockGroup,
            args: { name: "test-group" },
            children: [{ block: NestedChildBlock }],
          },
        ],
        getOwner(this)
      );

      await render(<template><BlockOutlet @name="sidebar-blocks" /></template>);

      // BlockGroup is decorated with @block("group", { container: true })
      const groupContext = receivedContexts.find((c) => c.name === "group");
      const childContext = receivedContexts.find(
        (c) => c.name === "nested-child-block"
      );

      assert.strictEqual(
        groupContext.outletName,
        "sidebar-blocks",
        "container block receives outlet name as hierarchy"
      );
      assert.strictEqual(
        childContext.outletName,
        "sidebar-blocks/group[0]",
        "nested child receives parent container path with index"
      );
    });

    test("debugHooks.setCallback(BLOCK_DEBUG) receives correct hierarchy for deeply nested children", async function (assert) {
      @block("deep-nested-block")
      class DeepNestedBlock extends Component {
        <template>
          <div class="deep-nested">Deep Nested</div>
        </template>
      }

      const receivedContexts = [];

      debugHooks.setCallback(
        DEBUG_CALLBACK.BLOCK_DEBUG,
        (blockData, context) => {
          receivedContexts.push({
            name: blockData.name,
            outletName: context?.outletName,
          });
          return { Component: blockData.Component };
        }
      );

      withTestBlockRegistration(() => _registerBlock(DeepNestedBlock));
      renderBlocks(
        "hero-blocks",
        [
          {
            block: BlockGroup,
            args: { name: "outer" },
            children: [
              {
                block: BlockGroup,
                args: { name: "inner" },
                children: [{ block: DeepNestedBlock }],
              },
            ],
          },
        ],
        getOwner(this)
      );

      await render(<template><BlockOutlet @name="hero-blocks" /></template>);

      // BlockGroup is decorated with @block("group", { container: true })
      const outerContext = receivedContexts.find(
        (c) => c.name === "group" && c.outletName === "hero-blocks"
      );
      const innerContext = receivedContexts.find(
        (c) => c.name === "group" && c.outletName === "hero-blocks/group[0]"
      );
      const deepContext = receivedContexts.find(
        (c) => c.name === "deep-nested-block"
      );

      assert.strictEqual(
        outerContext.outletName,
        "hero-blocks",
        "outer container receives outlet name"
      );
      assert.strictEqual(
        innerContext.outletName,
        "hero-blocks/group[0]",
        "inner container receives parent path with index"
      );
      assert.strictEqual(
        deepContext.outletName,
        "hero-blocks/group[0]/group[0]",
        "deeply nested child receives full hierarchy path"
      );
    });

    test("debugHooks.setCallback(BLOCK_DEBUG) includes index for multiple containers at same level", async function (assert) {
      @block("multi-container-child")
      class MultiContainerChild extends Component {
        <template>
          <div class="multi-child">Multi Child</div>
        </template>
      }

      const receivedContexts = [];

      debugHooks.setCallback(
        DEBUG_CALLBACK.BLOCK_DEBUG,
        (blockData, context) => {
          receivedContexts.push({
            name: blockData.name,
            outletName: context?.outletName,
          });
          return { Component: blockData.Component };
        }
      );

      withTestBlockRegistration(() => _registerBlock(MultiContainerChild));
      renderBlocks(
        "main-outlet-blocks",
        [
          {
            block: BlockGroup,
            args: { name: "first" },
            children: [{ block: MultiContainerChild }],
          },
          {
            block: BlockGroup,
            args: { name: "second" },
            children: [{ block: MultiContainerChild }],
          },
        ],
        getOwner(this)
      );

      await render(
        <template><BlockOutlet @name="main-outlet-blocks" /></template>
      );

      // BlockGroup is decorated with @block("group", { container: true })
      const childContexts = receivedContexts.filter(
        (c) => c.name === "multi-container-child"
      );

      assert.strictEqual(childContexts.length, 2, "two children rendered");
      assert.strictEqual(
        childContexts[0].outletName,
        "main-outlet-blocks/group[0]",
        "first container child has index 0"
      );
      assert.strictEqual(
        childContexts[1].outletName,
        "main-outlet-blocks/group[1]",
        "second container child has index 1"
      );
    });

    test("debug overlay displays correct hierarchy for nested children (not overwritten by template)", async function (assert) {
      // This test ensures the debugLocation prop is not overwritten by the
      // template's @outletName when rendering children. The debug wrapper
      // must use a separate prop (debugLocation) to avoid this collision.
      @block("hierarchy-display-block")
      class HierarchyDisplayBlock extends Component {
        <template>
          <div class="hierarchy-display">Content</div>
        </template>
      }

      debugHooks.setCallback(
        DEBUG_CALLBACK.BLOCK_DEBUG,
        (blockData, context) => {
          // Wrap with a component that displays the hierarchy, simulating BlockInfo
          const debugLocation = context?.outletName;
          return {
            Component: <template>
              <div
                class="debug-wrapper"
                data-block-name={{blockData.name}}
                data-debug-location={{debugLocation}}
              >
                <blockData.Component />
              </div>
            </template>,
          };
        }
      );

      withTestBlockRegistration(() => _registerBlock(HierarchyDisplayBlock));
      renderBlocks(
        "header-blocks",
        [
          {
            block: BlockGroup,
            args: { name: "test" },
            children: [{ block: HierarchyDisplayBlock }],
          },
        ],
        getOwner(this)
      );

      await render(<template><BlockOutlet @name="header-blocks" /></template>);

      // The nested child should have the full hierarchy path, NOT just "header-blocks"
      const nestedChildWrapper = document.querySelector(
        '.debug-wrapper[data-block-name="hierarchy-display-block"]'
      );

      assert.strictEqual(
        nestedChildWrapper.dataset.debugLocation,
        "header-blocks/group[0]",
        "nested child displays full hierarchy path (not overwritten by template's @outletName)"
      );

      // The container itself should show the outlet name
      const containerWrapper = document.querySelector(
        '.debug-wrapper[data-block-name="group"]'
      );

      assert.strictEqual(
        containerWrapper.dataset.debugLocation,
        "header-blocks",
        "container displays outlet name as its location"
      );
    });
  });

  module("logging callbacks", function () {
    test("debugHooks.setCallback(BLOCK_LOGGING) enables console logging when returns true", async function (assert) {
      @block("logging-test-block")
      class LoggingTestBlock extends Component {
        <template>
          <div class="logging-content">Content</div>
        </template>
      }

      let consoleCalled = false;
      debugHooks.setCallback(DEBUG_CALLBACK.BLOCK_LOGGING, () => true);
      debugHooks.setCallback(
        DEBUG_CALLBACK.START_GROUP,
        () => (consoleCalled = true)
      );

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

      assert.true(consoleCalled, "console logging was enabled");
    });

    test("debugHooks.setCallback(BLOCK_LOGGING) disables logging when returns false", async function (assert) {
      @block("no-logging-block")
      class NoLoggingBlock extends Component {
        <template>
          <div class="no-logging-content">Content</div>
        </template>
      }

      const consoleStub = sinon.stub(console, "groupCollapsed");

      debugHooks.setCallback(DEBUG_CALLBACK.BLOCK_LOGGING, () => false);

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

  module("outlet boundary callbacks", function () {
    test("debugHooks.setCallback(OUTLET_BOUNDARY) shows boundary when returns true", async function (assert) {
      @block("boundary-test-block")
      class BoundaryTestBlock extends Component {
        <template>
          <div class="boundary-content">Content</div>
        </template>
      }

      debugHooks.setCallback(DEBUG_CALLBACK.OUTLET_BOUNDARY, () => true);

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

    test("debugHooks.setCallback(OUTLET_BOUNDARY) hides boundary when returns false", async function (assert) {
      @block("no-boundary-block")
      class NoBoundaryBlock extends Component {
        <template>
          <div class="no-boundary-content">Content</div>
        </template>
      }

      debugHooks.setCallback(DEBUG_CALLBACK.OUTLET_BOUNDARY, () => false);

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

    test("debugHooks.setCallback(OUTLET_BOUNDARY) can be cleared by setting to null", async function (assert) {
      @block("boundary-clear-block")
      class BoundaryClearBlock extends Component {
        <template>
          <div class="boundary-clear-content">Content</div>
        </template>
      }

      debugHooks.setCallback(DEBUG_CALLBACK.OUTLET_BOUNDARY, () => true);
      debugHooks.setCallback(DEBUG_CALLBACK.OUTLET_BOUNDARY, null);

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

  module("deeply nested containers", function () {
    test("renders 5+ levels of nested container blocks", async function (assert) {
      @block("leaf-block", { args: { depth: { type: "string" } } })
      class LeafBlock extends Component {
        <template>
          <div class="leaf-block" data-depth={{@depth}}>
            Leaf at depth
            {{@depth}}
          </div>
        </template>
      }

      withTestBlockRegistration(() => {
        _registerBlock(LeafBlock);
      });

      const buildNestedConfig = (depth, maxDepth) => {
        if (depth >= maxDepth) {
          return [
            { block: LeafBlock, args: { depth: depth.toString() } },
            { block: LeafBlock, args: { depth: depth.toString() } },
          ];
        }

        return [
          {
            block: BlockGroup,
            args: { name: `level-${depth}` },
            children: buildNestedConfig(depth + 1, maxDepth),
          },
          {
            block: BlockGroup,
            args: { name: `level-${depth}-alt` },
            children: buildNestedConfig(depth + 1, maxDepth),
          },
        ];
      };

      renderBlocks("homepage-blocks", buildNestedConfig(0, 5));

      await render(
        <template><BlockOutlet @name="homepage-blocks" /></template>
      );

      assert.dom(".homepage-blocks").exists("outlet renders");

      assert.dom(".block__group-level-0").exists("level 0 group exists");
      assert.dom(".block__group-level-1").exists("level 1 group exists");
      assert.dom(".block__group-level-2").exists("level 2 group exists");
      assert.dom(".block__group-level-3").exists("level 3 group exists");
      assert.dom(".block__group-level-4").exists("level 4 group exists");

      const leafBlocks = document.querySelectorAll(".leaf-block");
      assert.strictEqual(
        leafBlocks.length,
        64,
        "all 64 leaf blocks render (2^6 from binary tree)"
      );

      const depth5Leaves = document.querySelectorAll(
        '.leaf-block[data-depth="5"]'
      );
      assert.strictEqual(
        depth5Leaves.length,
        64,
        "all leaf blocks are at depth 5"
      );
    });

    test("deeply nested blocks do not cause stack overflow", async function (assert) {
      @block("deep-leaf-block")
      class DeepLeafBlock extends Component {
        <template>
          <div class="deep-leaf">Deep Leaf</div>
        </template>
      }

      withTestBlockRegistration(() => {
        _registerBlock(DeepLeafBlock);
      });

      const buildDeeplyNestedConfig = (depth) => {
        if (depth <= 0) {
          return [{ block: DeepLeafBlock }];
        }

        return [
          {
            block: BlockGroup,
            args: { name: `deep-${depth}` },
            children: buildDeeplyNestedConfig(depth - 1),
          },
        ];
      };

      renderBlocks("sidebar-blocks", buildDeeplyNestedConfig(10));

      await render(<template><BlockOutlet @name="sidebar-blocks" /></template>);

      assert.dom(".sidebar-blocks").exists("outlet renders");

      assert.dom(".block__group-deep-10").exists("deepest group exists");
      assert.dom(".block__group-deep-1").exists("shallowest group exists");
      assert.dom(".deep-leaf").exists("leaf block renders at bottom");
    });

    test("nested containers with conditions at multiple levels", async function (assert) {
      @block("conditional-leaf", { args: { level: { type: "string" } } })
      class ConditionalLeaf extends Component {
        <template>
          <div class="conditional-leaf" data-level={{@level}}>
            Level
            {{@level}}
          </div>
        </template>
      }

      withTestBlockRegistration(() => {
        _registerBlock(ConditionalLeaf);
      });

      renderBlocks("main-outlet-blocks", [
        {
          block: BlockGroup,
          args: { name: "outer" },
          children: [
            {
              block: BlockGroup,
              args: { name: "middle-1" },
              children: [
                {
                  block: ConditionalLeaf,
                  args: { level: "3a" },
                  conditions: { type: "user", loggedIn: false },
                },
                {
                  block: ConditionalLeaf,
                  args: { level: "3b" },
                },
              ],
            },
            {
              block: BlockGroup,
              args: { name: "middle-2" },
              conditions: { type: "user", loggedIn: false },
              children: [{ block: ConditionalLeaf, args: { level: "3c" } }],
            },
          ],
        },
      ]);

      await render(
        <template><BlockOutlet @name="main-outlet-blocks" /></template>
      );

      assert.dom(".block__group-outer").exists("outer group renders");
      assert.dom(".block__group-middle-1").exists("middle-1 group renders");
      assert
        .dom('.conditional-leaf[data-level="3a"]')
        .doesNotExist("conditional leaf 3a hidden (logged out required)");
      assert
        .dom('.conditional-leaf[data-level="3b"]')
        .exists("unconditional leaf 3b renders");
      assert
        .dom(".block__group-middle-2")
        .doesNotExist("middle-2 group hidden (logged out required)");
      assert
        .dom('.conditional-leaf[data-level="3c"]')
        .doesNotExist("leaf 3c hidden (parent hidden)");
    });
  });

  module("string block references", function () {
    test("renders block using string name reference", async function (assert) {
      @block("string-ref-block")
      class StringRefBlock extends Component {
        <template>
          <div class="string-ref-content">String Referenced Block</div>
        </template>
      }

      withTestBlockRegistration(() => _registerBlock(StringRefBlock));
      renderBlocks("homepage-blocks", [{ block: "string-ref-block" }]);

      await render(
        <template><BlockOutlet @name="homepage-blocks" /></template>
      );

      assert.dom(".homepage-blocks").exists("outlet renders");
      assert
        .dom(".string-ref-content")
        .hasText("String Referenced Block", "string-referenced block renders");
    });

    test("passes args to string-referenced block", async function (assert) {
      @block("string-args-block", {
        args: {
          title: { type: "string" },
          count: { type: "number" },
        },
      })
      class StringArgsBlock extends Component {
        <template>
          <div class="string-args-content">
            <span class="title">{{@title}}</span>
            <span class="count">{{@count}}</span>
          </div>
        </template>
      }

      withTestBlockRegistration(() => _registerBlock(StringArgsBlock));
      renderBlocks("header-blocks", [
        { block: "string-args-block", args: { title: "Hello", count: 42 } },
      ]);

      await render(<template><BlockOutlet @name="header-blocks" /></template>);

      assert.dom(".string-args-content .title").hasText("Hello");
      assert.dom(".string-args-content .count").hasText("42");
    });

    test("mixed class and string references work together", async function (assert) {
      @block("class-ref-block")
      class ClassRefBlock extends Component {
        <template>
          <div class="class-ref-content">Class Reference</div>
        </template>
      }

      @block("string-mixed-block")
      class StringMixedBlock extends Component {
        <template>
          <div class="string-mixed-content">String Reference</div>
        </template>
      }

      withTestBlockRegistration(() => {
        _registerBlock(ClassRefBlock);
        _registerBlock(StringMixedBlock);
      });

      renderBlocks("hero-blocks", [
        { block: ClassRefBlock },
        { block: "string-mixed-block" },
      ]);

      await render(<template><BlockOutlet @name="hero-blocks" /></template>);

      assert.dom(".hero-blocks").exists("outlet renders");
      assert
        .dom(".class-ref-content")
        .hasText("Class Reference", "class-referenced block renders");
      assert
        .dom(".string-mixed-content")
        .hasText("String Reference", "string-referenced block renders");
    });

    test("string reference in nested container children", async function (assert) {
      @block("nested-string-block")
      class NestedStringBlock extends Component {
        <template>
          <div class="nested-string-content">Nested String Block</div>
        </template>
      }

      withTestBlockRegistration(() => _registerBlock(NestedStringBlock));

      renderBlocks("main-outlet-blocks", [
        {
          block: BlockGroup,
          args: { name: "container" },
          children: [{ block: "nested-string-block" }],
        },
      ]);

      await render(
        <template><BlockOutlet @name="main-outlet-blocks" /></template>
      );

      assert.dom(".block__group-container").exists("container renders");
      assert
        .dom(".nested-string-content")
        .hasText(
          "Nested String Block",
          "nested string-referenced block renders"
        );
    });

    test("renders block from factory function", async function (assert) {
      @block("factory-render-block")
      class FactoryRenderBlock extends Component {
        <template>
          <div class="factory-render-content">Factory Loaded Block</div>
        </template>
      }

      withTestBlockRegistration(() =>
        _registerBlockFactory(
          "factory-render-block",
          async () => FactoryRenderBlock
        )
      );
      renderBlocks("sidebar-blocks", [{ block: "factory-render-block" }]);

      await render(<template><BlockOutlet @name="sidebar-blocks" /></template>);

      assert.dom(".sidebar-blocks").exists("outlet renders");
      assert
        .dom(".factory-render-content")
        .hasText("Factory Loaded Block", "factory-registered block renders");
    });

    test("handles factory returning module with default export", async function (assert) {
      @block("default-export-block")
      class DefaultExportBlock extends Component {
        <template>
          <div class="default-export-content">Default Export Block</div>
        </template>
      }

      withTestBlockRegistration(() =>
        _registerBlockFactory("default-export-block", async () => ({
          default: DefaultExportBlock,
        }))
      );
      renderBlocks("hero-blocks", [{ block: "default-export-block" }]);

      await render(<template><BlockOutlet @name="hero-blocks" /></template>);

      assert.dom(".hero-blocks").exists("outlet renders");
      assert
        .dom(".default-export-content")
        .hasText("Default Export Block", "block from default export renders");
    });
  });

  module("optional blocks", function () {
    test("missing optional block is silently skipped (no error)", async function (assert) {
      @block("required-block")
      class RequiredBlock extends Component {
        <template>
          <div class="required-content">Required Block</div>
        </template>
      }

      withTestBlockRegistration(() => _registerBlock(RequiredBlock));

      // Configure with one required block and one optional missing block
      renderBlocks("hero-blocks", [
        { block: RequiredBlock },
        { block: "non-existent-block?" }, // Optional - should silently skip
      ]);

      // Should not throw error
      await render(<template><BlockOutlet @name="hero-blocks" /></template>);

      assert.dom(".hero-blocks").exists("outlet renders");
      assert.dom(".required-content").hasText("Required Block");
    });

    test("present optional block renders normally", async function (assert) {
      @block("present-optional-block")
      class PresentOptionalBlock extends Component {
        <template>
          <div class="present-optional-content">Present Optional</div>
        </template>
      }

      withTestBlockRegistration(() => _registerBlock(PresentOptionalBlock));

      renderBlocks("sidebar-blocks", [
        { block: "present-optional-block?" }, // Optional but present
      ]);

      await render(<template><BlockOutlet @name="sidebar-blocks" /></template>);

      assert.dom(".sidebar-blocks").exists("outlet renders");
      assert
        .dom(".present-optional-content")
        .hasText("Present Optional", "optional block renders when present");
    });

    test("mix of required and optional blocks renders correctly", async function (assert) {
      @block("mix-required-block")
      class MixRequiredBlock extends Component {
        <template>
          <div class="mix-required">Required</div>
        </template>
      }

      @block("mix-optional-present")
      class MixOptionalPresent extends Component {
        <template>
          <div class="mix-optional-present">Optional Present</div>
        </template>
      }

      withTestBlockRegistration(() => {
        _registerBlock(MixRequiredBlock);
        _registerBlock(MixOptionalPresent);
      });

      renderBlocks("main-outlet-blocks", [
        { block: MixRequiredBlock },
        { block: "missing-optional-block?" }, // Optional missing - skipped
        { block: "mix-optional-present?" }, // Optional present - rendered
      ]);

      await render(
        <template><BlockOutlet @name="main-outlet-blocks" /></template>
      );

      assert.dom(".main-outlet-blocks").exists("outlet renders");
      assert.dom(".mix-required").exists("required block renders");
      assert
        .dom(".mix-optional-present")
        .exists("optional present block renders");
    });

    test("multiple missing optional blocks all skipped", async function (assert) {
      @block("single-required")
      class SingleRequired extends Component {
        <template>
          <div class="single-required-content">Only Required</div>
        </template>
      }

      withTestBlockRegistration(() => _registerBlock(SingleRequired));

      renderBlocks("homepage-blocks", [
        { block: "missing-1?" },
        { block: "missing-2?" },
        { block: SingleRequired },
        { block: "missing-3?" },
      ]);

      await render(
        <template><BlockOutlet @name="homepage-blocks" /></template>
      );

      assert.dom(".homepage-blocks").exists("outlet renders");
      assert
        .dom(".single-required-content")
        .hasText(
          "Only Required",
          "required block renders among multiple optional missing"
        );
    });

    test("optional namespaced blocks work correctly", async function (assert) {
      @block("chat:optional-widget")
      class OptionalWidget extends Component {
        <template>
          <div class="optional-widget-content">Namespaced Optional</div>
        </template>
      }

      withTestBlockRegistration(() => _registerBlock(OptionalWidget));

      renderBlocks("header-blocks", [
        { block: "chat:optional-widget?" }, // Present namespaced optional
        { block: "chat:missing-widget?" }, // Missing namespaced optional
      ]);

      await render(<template><BlockOutlet @name="header-blocks" /></template>);

      assert.dom(".header-blocks").exists("outlet renders");
      assert
        .dom(".optional-widget-content")
        .hasText("Namespaced Optional", "present namespaced optional renders");
    });

    test("optional missing block shows ghost when debug callback enabled", async function (assert) {
      @block("ghost-test-block")
      class GhostTestBlock extends Component {
        <template>
          <div class="ghost-test-content">Ghost Test</div>
        </template>
      }

      let ghostBlockData = null;

      debugHooks.setCallback(DEBUG_CALLBACK.VISUAL_OVERLAY, () => true);
      debugHooks.setCallback(
        DEBUG_CALLBACK.BLOCK_DEBUG,
        (blockData, context) => {
          if (blockData.optionalMissing) {
            ghostBlockData = { ...blockData, context };
            return {
              Component: <template>
                <div
                  class="ghost-block"
                  data-name={{blockData.name}}
                >Ghost</div>
              </template>,
            };
          }
          return { Component: blockData.Component };
        }
      );

      withTestBlockRegistration(() => _registerBlock(GhostTestBlock));

      renderBlocks("sidebar-blocks", [
        { block: GhostTestBlock },
        { block: "missing-optional-block?", args: { foo: "bar" } },
      ]);

      await render(<template><BlockOutlet @name="sidebar-blocks" /></template>);

      assert.dom(".sidebar-blocks").exists("outlet renders");
      assert.dom(".ghost-test-content").exists("required block renders");
      assert
        .dom('.ghost-block[data-name="missing-optional-block"]')
        .exists("ghost block shown for optional missing");

      assert.strictEqual(
        ghostBlockData.name,
        "missing-optional-block",
        "ghost receives correct block name"
      );
      assert.true(
        ghostBlockData.optionalMissing,
        "ghost receives optionalMissing flag"
      );
      assert.deepEqual(
        ghostBlockData.args,
        { foo: "bar" },
        "ghost receives original args"
      );
    });
  });

  module("outlet args", function () {
    test("blocks receive @outletArgs separately from config args", async function (assert) {
      let receivedArgs = null;
      let receivedOutletArgs = null;

      @block("outlet-args-test-block", {
        args: { title: { type: "string" }, count: { type: "number" } },
      })
      class OutletArgsTestBlock extends Component {
        constructor() {
          super(...arguments);
          receivedArgs = { title: this.args.title, count: this.args.count };
          receivedOutletArgs = this.args.outletArgs;
        }

        <template>
          <div class="outlet-args-test">
            <span class="title">{{@title}}</span>
            <span class="topic">{{@outletArgs.topic.title}}</span>
          </div>
        </template>
      }

      withTestBlockRegistration(() => _registerBlock(OutletArgsTestBlock));
      renderBlocks("homepage-blocks", [
        { block: OutletArgsTestBlock, args: { title: "Hello", count: 42 } },
      ]);

      const outletArgs = {
        topic: { title: "Test Topic" },
        category: { id: 5 },
      };

      await render(
        <template>
          <BlockOutlet @name="homepage-blocks" @outletArgs={{outletArgs}} />
        </template>
      );

      assert.strictEqual(receivedArgs.title, "Hello", "config arg received");
      assert.strictEqual(receivedArgs.count, 42, "config arg received");
      assert.strictEqual(
        receivedOutletArgs.topic.title,
        "Test Topic",
        "outlet arg accessible"
      );
      assert.strictEqual(
        receivedOutletArgs.category.id,
        5,
        "outlet arg accessible"
      );
      assert.dom(".outlet-args-test .title").hasText("Hello");
      assert.dom(".outlet-args-test .topic").hasText("Test Topic");
    });

    test("BlockGroup forwards @outletArgs to children", async function (assert) {
      let receivedOutletArgs = null;

      @block("group-child-block")
      class GroupChildBlock extends Component {
        constructor() {
          super(...arguments);
          receivedOutletArgs = this.args.outletArgs;
        }

        <template>
          <div class="group-child-content">
            {{@outletArgs.topic.title}}
          </div>
        </template>
      }

      withTestBlockRegistration(() => _registerBlock(GroupChildBlock));
      renderBlocks(
        "sidebar-blocks",
        [
          {
            block: BlockGroup,
            args: { name: "test" },
            children: [{ block: GroupChildBlock }],
          },
        ],
        getOwner(this)
      );

      const outletArgs = { topic: { title: "Forwarded Topic" } };

      await render(
        <template>
          <BlockOutlet @name="sidebar-blocks" @outletArgs={{outletArgs}} />
        </template>
      );

      assert.strictEqual(
        receivedOutletArgs.topic.title,
        "Forwarded Topic",
        "outlet args forwarded through BlockGroup"
      );
      assert.dom(".group-child-content").hasText("Forwarded Topic");
    });

    test("nested containers forward @outletArgs through hierarchy", async function (assert) {
      let receivedOutletArgs = null;

      @block("deep-nested-outlet-args-block")
      class DeepNestedBlock extends Component {
        constructor() {
          super(...arguments);
          receivedOutletArgs = this.args.outletArgs;
        }

        <template>
          <div class="deep-nested-content">
            {{@outletArgs.user.name}}
          </div>
        </template>
      }

      withTestBlockRegistration(() => _registerBlock(DeepNestedBlock));
      renderBlocks(
        "hero-blocks",
        [
          {
            block: BlockGroup,
            args: { name: "outer" },
            children: [
              {
                block: BlockGroup,
                args: { name: "inner" },
                children: [{ block: DeepNestedBlock }],
              },
            ],
          },
        ],
        getOwner(this)
      );

      const outletArgs = { user: { name: "Deep User" } };

      await render(
        <template>
          <BlockOutlet @name="hero-blocks" @outletArgs={{outletArgs}} />
        </template>
      );

      assert.strictEqual(
        receivedOutletArgs.user.name,
        "Deep User",
        "outlet args passed through nested containers"
      );
      assert.dom(".deep-nested-content").hasText("Deep User");
    });

    test("outlet args are available for condition evaluation", async function (assert) {
      @block("conditional-outlet-args-block")
      class ConditionalBlock extends Component {
        <template>
          <div class="conditional-content">Conditional</div>
        </template>
      }

      withTestBlockRegistration(() => _registerBlock(ConditionalBlock));
      renderBlocks(
        "main-outlet-blocks",
        [
          {
            block: ConditionalBlock,
            conditions: {
              type: "outletArg",
              path: "topic.closed",
              value: true,
            },
          },
        ],
        getOwner(this)
      );

      // Condition should pass - topic is closed
      const closedTopicArgs = { topic: { closed: true } };
      await render(
        <template>
          <BlockOutlet
            @name="main-outlet-blocks"
            @outletArgs={{closedTopicArgs}}
          />
        </template>
      );

      assert
        .dom(".conditional-content")
        .exists("block renders when outletArg condition passes");
    });

    test("outlet args condition can fail", async function (assert) {
      @block("failing-condition-block")
      class FailingConditionBlock extends Component {
        <template>
          <div class="failing-condition-content">Should not render</div>
        </template>
      }

      withTestBlockRegistration(() => _registerBlock(FailingConditionBlock));
      renderBlocks(
        "header-blocks",
        [
          {
            block: FailingConditionBlock,
            conditions: {
              type: "outletArg",
              path: "topic.closed",
              value: true,
            },
          },
        ],
        getOwner(this)
      );

      // Condition should fail - topic is not closed
      const openTopicArgs = { topic: { closed: false } };
      await render(
        <template>
          <BlockOutlet @name="header-blocks" @outletArgs={{openTopicArgs}} />
        </template>
      );

      assert
        .dom(".failing-condition-content")
        .doesNotExist("block does not render when outletArg condition fails");
    });

    test("debug callback receives outletArgs in context", async function (assert) {
      let receivedContext = null;

      debugHooks.setCallback(
        DEBUG_CALLBACK.BLOCK_DEBUG,
        (blockData, context) => {
          receivedContext = context;
          return { Component: blockData.Component };
        }
      );

      @block("debug-outlet-args-block")
      class DebugOutletArgsBlock extends Component {
        <template>
          <div class="debug-outlet-args-content">Debug</div>
        </template>
      }

      withTestBlockRegistration(() => _registerBlock(DebugOutletArgsBlock));
      renderBlocks("sidebar-blocks", [{ block: DebugOutletArgsBlock }]);

      const outletArgs = { topic: { id: 123 }, user: { name: "Test" } };

      await render(
        <template>
          <BlockOutlet @name="sidebar-blocks" @outletArgs={{outletArgs}} />
        </template>
      );

      assert.deepEqual(
        receivedContext.outletArgs,
        outletArgs,
        "debug callback receives outletArgs in context"
      );
    });
  });

  module("error handling", function () {
    test("outlet continues rendering other blocks when one block throws", async function (assert) {
      let errorCaught = null;
      setupOnerror((error) => {
        errorCaught = error;
      });

      @block("throwing-block")
      class ThrowingBlock extends Component {
        constructor() {
          super(...arguments);
          throw new Error("Block render error");
        }

        <template>
          <div class="throwing-content">Should not render</div>
        </template>
      }

      @block("safe-block")
      class SafeBlock extends Component {
        <template>
          <div class="safe-content">Safe Content</div>
        </template>
      }

      withTestBlockRegistration(() => {
        _registerBlock(ThrowingBlock);
        _registerBlock(SafeBlock);
      });
      renderBlocks("homepage-blocks", [
        { block: SafeBlock },
        { block: ThrowingBlock },
      ]);

      await render(
        <template><BlockOutlet @name="homepage-blocks" /></template>
      );

      assert.notStrictEqual(errorCaught, null, "error was caught");
      assert.true(
        errorCaught?.message?.includes("Block render error"),
        "error message is correct"
      );
    });

    test("block with invalid condition type shows warning in dev mode", async function (assert) {
      @block("invalid-condition-block")
      class InvalidConditionBlock extends Component {
        <template>
          <div class="invalid-condition-content">Content</div>
        </template>
      }

      withTestBlockRegistration(() => _registerBlock(InvalidConditionBlock));

      const blocks = getOwner(this).lookup("service:blocks");

      // Using an unknown condition type should return false (fail silently)
      const result = blocks.evaluate({ type: "unknown-condition-type" });
      assert.false(
        result,
        "unknown condition type evaluates to false (fails closed)"
      );
    });

    test("block with null conditions renders normally", async function (assert) {
      @block("null-conditions-block")
      class NullConditionsBlock extends Component {
        <template>
          <div class="null-conditions-content">Renders</div>
        </template>
      }

      withTestBlockRegistration(() => _registerBlock(NullConditionsBlock));
      renderBlocks("sidebar-blocks", [
        { block: NullConditionsBlock, conditions: null },
      ]);

      await render(<template><BlockOutlet @name="sidebar-blocks" /></template>);

      assert
        .dom(".null-conditions-content")
        .exists("block renders with null conditions");
    });

    test("block with undefined conditions renders normally", async function (assert) {
      @block("undefined-conditions-block")
      class UndefinedConditionsBlock extends Component {
        <template>
          <div class="undefined-conditions-content">Renders</div>
        </template>
      }

      withTestBlockRegistration(() => _registerBlock(UndefinedConditionsBlock));
      renderBlocks("hero-blocks", [
        { block: UndefinedConditionsBlock, conditions: undefined },
      ]);

      await render(<template><BlockOutlet @name="hero-blocks" /></template>);

      assert
        .dom(".undefined-conditions-content")
        .exists("block renders with undefined conditions");
    });

    test("validation errors cause test failures", async function (assert) {
      @block("validation-error-block")
      class ValidationErrorBlock extends Component {
        <template>
          <div class="validation-error-content">Content</div>
        </template>
      }

      withTestBlockRegistration(() => _registerBlock(ValidationErrorBlock));

      // The validation promise rejects when conditions are invalid.
      // In tests, unhandled promise rejections cause test failures.
      // We can access the validation promise via the internal outletLayouts.
      renderBlocks(
        "main-outlet-blocks",
        [
          {
            block: ValidationErrorBlock,
            conditions: { type: "outletArg" }, // missing required "path"
          },
        ],
        getOwner(this)
      );

      // Access the validation promise to catch the expected error
      const layoutData = _getOutletLayouts().get("main-outlet-blocks");

      await assert.rejects(
        layoutData.validatedLayout,
        /`path` argument is required/,
        "validation error thrown for missing required path argument"
      );
    });
  });
});
