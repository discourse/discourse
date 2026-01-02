import Component from "@glimmer/component";
import { getOwner } from "@ember/owner";
import { render, setupOnerror } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import BlockGroup from "discourse/blocks/block-group";
import BlockOutlet, {
  block,
  renderBlocks,
} from "discourse/components/block-outlet";
import {
  _setBlockDebugCallback,
  _setBlockLoggingCallback,
  _setBlockOutletBoundaryCallback,
} from "discourse/lib/blocks/debug-hooks";
import {
  _registerBlock,
  withTestBlockRegistration,
} from "discourse/lib/blocks/registration";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Blocks | BlockOutlet", function (hooks) {
  setupRenderingTest(hooks);

  hooks.afterEach(function () {
    _setBlockDebugCallback(null);
    _setBlockLoggingCallback(null);
    _setBlockOutletBoundaryCallback(null);
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
      @block("args-test-block")
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

      setupOnerror();
    });
  });

  module("debug callbacks", function () {
    test("_setBlockDebugCallback wraps rendered blocks", async function (assert) {
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

    test("_setBlockDebugCallback shows ghost blocks when conditions fail", async function (assert) {
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

    test("_setBlockDebugCallback can be cleared by setting to null", async function (assert) {
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

    test("_setBlockDebugCallback receives correct hierarchy for direct children", async function (assert) {
      @block("direct-child-block")
      class DirectChildBlock extends Component {
        <template>
          <div class="direct-child">Direct Child</div>
        </template>
      }

      const receivedContexts = [];

      _setBlockDebugCallback((blockData, context) => {
        receivedContexts.push({
          name: blockData.name,
          outletName: context.outletName,
        });
        return { Component: blockData.Component };
      });

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

    test("_setBlockDebugCallback receives correct hierarchy for children of container blocks", async function (assert) {
      @block("nested-child-block")
      class NestedChildBlock extends Component {
        <template>
          <div class="nested-child">Nested Child</div>
        </template>
      }

      const receivedContexts = [];

      _setBlockDebugCallback((blockData, context) => {
        receivedContexts.push({
          name: blockData.name,
          outletName: context?.outletName,
        });
        return { Component: blockData.Component };
      });

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

    test("_setBlockDebugCallback receives correct hierarchy for deeply nested children", async function (assert) {
      @block("deep-nested-block")
      class DeepNestedBlock extends Component {
        <template>
          <div class="deep-nested">Deep Nested</div>
        </template>
      }

      const receivedContexts = [];

      _setBlockDebugCallback((blockData, context) => {
        receivedContexts.push({
          name: blockData.name,
          outletName: context?.outletName,
        });
        return { Component: blockData.Component };
      });

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

    test("_setBlockDebugCallback includes index for multiple containers at same level", async function (assert) {
      @block("multi-container-child")
      class MultiContainerChild extends Component {
        <template>
          <div class="multi-child">Multi Child</div>
        </template>
      }

      const receivedContexts = [];

      _setBlockDebugCallback((blockData, context) => {
        receivedContexts.push({
          name: blockData.name,
          outletName: context?.outletName,
        });
        return { Component: blockData.Component };
      });

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

      _setBlockDebugCallback((blockData, context) => {
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
      });

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
    test("_setBlockLoggingCallback enables console logging when returns true", async function (assert) {
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

    test("_setBlockLoggingCallback disables logging when returns false", async function (assert) {
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

  module("outlet boundary callbacks", function () {
    test("_setBlockOutletBoundaryCallback shows boundary when returns true", async function (assert) {
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

    test("_setBlockOutletBoundaryCallback hides boundary when returns false", async function (assert) {
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

    test("_setBlockOutletBoundaryCallback can be cleared by setting to null", async function (assert) {
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

  module("deeply nested containers", function () {
    test("renders 5+ levels of nested container blocks", async function (assert) {
      @block("leaf-block")
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
      @block("conditional-leaf")
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
});
