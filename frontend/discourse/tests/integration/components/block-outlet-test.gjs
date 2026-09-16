import Component from "@glimmer/component";
import { getOwner } from "@ember/owner";
import {
  clearRender,
  find,
  render,
  settled,
  setupOnerror,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { block } from "discourse/blocks";
import BlockOutlet, {
  _getOutletLayouts,
  _setLayoutLayer,
  LAYOUT_LAYERS,
} from "discourse/blocks/block-outlet";
import BlockGroup from "discourse/blocks/builtin/block-group";
import { withPluginApi } from "discourse/lib/plugin-api";
import {
  DEBUG_CALLBACK,
  debugHooks,
  FAILURE_TYPE,
  registerBlock,
  registerBlockFactory,
  withTestBlockRegistration,
} from "discourse/tests/helpers/block-testing";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Blocks | BlockOutlet", function (hooks) {
  setupRenderingTest(hooks);

  hooks.afterEach(function () {
    setupOnerror();
  });

  module("mounted outlet registry", function () {
    test("the blocks service tracks a mounted outlet (even with no layout) and clears it on teardown", async function (assert) {
      const blocks = getOwner(this).lookup("service:blocks");
      assert.false(
        blocks.mountedOutletNames().has("hero-blocks"),
        "not tracked before the outlet renders"
      );

      await render(<template><BlockOutlet @name="hero-blocks" /></template>);
      assert.true(
        blocks.mountedOutletNames().has("hero-blocks"),
        "tracked while mounted, despite having no layout"
      );

      await clearRender();
      assert.false(
        blocks.mountedOutletNames().has("hero-blocks"),
        "untracked once the outlet is torn down"
      );
    });
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

      withPluginApi((api) =>
        api.renderBlocks("homepage-blocks", [{ block: RenderTestBlock }])
      );

      await render(
        <template><BlockOutlet @name="homepage-blocks" /></template>
      );

      assert.dom(".homepage-blocks").exists();
      assert.dom(".render-test-content").hasText("Test Content");
    });

    test("re-renders when a locked layout is added after first paint", async function (assert) {
      @block("autotrack-seed-block")
      class SeedBlock extends Component {
        <template>
          <div class="seed-content">Seed</div>
        </template>
      }

      @block("autotrack-locked-block")
      class LockedBlock extends Component {
        <template>
          <div class="locked-content">Locked</div>
        </template>
      }

      withPluginApi((api) =>
        api.renderBlocks("homepage-blocks", [{ block: SeedBlock }])
      );

      await render(
        <template><BlockOutlet @name="homepage-blocks" /></template>
      );
      assert.dom(".seed-content").exists("the overridable seed renders first");

      // Register a locked layout AFTER the first paint. resolveLayoutRecord reads
      // tracked record fields, so the outlet must re-resolve and re-render — this
      // guards the autotracking of the new precedence chain.
      withPluginApi((api) =>
        api.renderBlocks("homepage-blocks", [{ block: LockedBlock }], {
          overridable: false,
        })
      );
      await settled();

      assert.dom(".locked-content").exists("the locked layout takes over");
      assert.dom(".seed-content").doesNotExist();
    });

    test("renders correct BEM class structure", async function (assert) {
      @block("bem-test-block")
      class BemTestBlock extends Component {
        <template>
          <span>BEM Test</span>
        </template>
      }

      withPluginApi((api) =>
        api.renderBlocks("sidebar-blocks", [{ block: BemTestBlock }])
      );

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

      withPluginApi((api) =>
        api.renderBlocks("main-outlet-blocks", [
          { block: WrappedBlock, classNames: "custom-class" },
        ])
      );

      await render(
        <template><BlockOutlet @name="main-outlet-blocks" /></template>
      );

      assert.dom(".main-outlet-blocks__block").exists();
      assert.dom('[data-block-name="wrapped-block"]').exists();
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

      withPluginApi((api) =>
        api.renderBlocks("hero-blocks", [
          { block: ArgsTestBlock, args: { title: "Hello", count: 42 } },
        ])
      );

      await render(<template><BlockOutlet @name="hero-blocks" /></template>);

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

      withPluginApi((api) =>
        api.renderBlocks("main-outlet-blocks", [{ block: DefaultsTestBlock }])
      );

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

      withPluginApi((api) =>
        api.renderBlocks("hero-blocks", [
          {
            block: OverrideDefaultsBlock,
            args: { title: "Custom Title", count: 99 },
          },
        ])
      );

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

      withPluginApi((api) =>
        api.renderBlocks("sidebar-blocks", [
          {
            block: PartialDefaultsBlock,
            args: { title: "Custom Title" },
          },
        ])
      );

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
      const stub = sinon.stub(console, "error");

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
      assert.true(stub.calledWithMatch("Error occurred:"));

      stub.restore();
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

      withPluginApi((api) =>
        api.renderBlocks("homepage-blocks", [{ block: DebugWrapBlock }])
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

      debugHooks.setCallback(DEBUG_CALLBACK.GHOST_BLOCKS, () => true);
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

      withPluginApi((api) =>
        api.renderBlocks("sidebar-blocks", [
          {
            block: GhostTestBlock,
            // loggedIn: false means "only for anonymous users" - fails when logged in
            conditions: { type: "user", loggedIn: false },
          },
        ])
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

      withPluginApi((api) =>
        api.renderBlocks("hero-blocks", [{ block: ClearCallbackBlock }])
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

      withPluginApi((api) =>
        api.renderBlocks("homepage-blocks", [{ block: DirectChildBlock }])
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

      withPluginApi((api) =>
        api.renderBlocks("sidebar-blocks", [
          {
            block: BlockGroup,

            children: [{ block: NestedChildBlock }],
          },
        ])
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

      withPluginApi((api) =>
        api.renderBlocks("hero-blocks", [
          {
            block: BlockGroup,

            children: [
              {
                block: BlockGroup,

                children: [{ block: DeepNestedBlock }],
              },
            ],
          },
        ])
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

      withPluginApi((api) =>
        api.renderBlocks("main-outlet-blocks", [
          {
            block: BlockGroup,

            children: [{ block: MultiContainerChild }],
          },
          {
            block: BlockGroup,

            children: [{ block: MultiContainerChild }],
          },
        ])
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

      withPluginApi((api) =>
        api.renderBlocks("hero-blocks", [
          {
            block: BlockGroup,

            children: [{ block: HierarchyDisplayBlock }],
          },
        ])
      );

      await render(<template><BlockOutlet @name="hero-blocks" /></template>);

      // The nested child should have the full hierarchy path, NOT just "hero-blocks"
      const nestedChildWrapper = document.querySelector(
        '.debug-wrapper[data-block-name="hierarchy-display-block"]'
      );

      assert.strictEqual(
        nestedChildWrapper.dataset.debugLocation,
        "hero-blocks/group[0]",
        "nested child displays full hierarchy path (not overwritten by template's @outletName)"
      );

      // The container itself should show the outlet name
      const containerWrapper = document.querySelector(
        '.debug-wrapper[data-block-name="group"]'
      );

      assert.strictEqual(
        containerWrapper.dataset.debugLocation,
        "hero-blocks",
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

      withPluginApi((api) =>
        api.renderBlocks("main-outlet-blocks", [
          {
            block: LoggingTestBlock,
            conditions: { type: "user", loggedIn: false },
          },
        ])
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

      withPluginApi((api) =>
        api.renderBlocks("hero-blocks", [
          {
            block: NoLoggingBlock,
            conditions: { type: "user", loggedIn: false },
          },
        ])
      );

      await render(<template><BlockOutlet @name="hero-blocks" /></template>);

      assert.false(consoleStub.called, "console logging was not enabled");
      consoleStub.restore();
    });
  });

  module("outlet boundary callbacks", function () {
    // Mock outlet info component for testing debug boundaries.
    // Must wrap content in .block-outlet-debug and yield children like the real OutletInfo.
    const MockOutletInfo = <template>
      <div class="block-outlet-debug">
        <span class="mock-outlet-info">{{@outletName}}</span>
        {{yield}}
      </div>
    </template>;

    test("debugHooks.setCallback(OUTLET_INFO_COMPONENT) shows boundary when returns component", async function (assert) {
      @block("boundary-test-block")
      class BoundaryTestBlock extends Component {
        <template>
          <div class="boundary-content">Content</div>
        </template>
      }

      debugHooks.setCallback(
        DEBUG_CALLBACK.OUTLET_INFO_COMPONENT,
        () => MockOutletInfo
      );

      withPluginApi((api) =>
        api.renderBlocks("homepage-blocks", [{ block: BoundaryTestBlock }])
      );

      await render(
        <template><BlockOutlet @name="homepage-blocks" /></template>
      );

      assert.dom(".block-outlet-debug").exists("debug boundary shown");
      assert.dom(".mock-outlet-info").exists("outlet info component rendered");
      assert.dom(".boundary-content").exists("content still renders");
    });

    test("debugHooks.setCallback(OUTLET_INFO_COMPONENT) hides boundary when returns null", async function (assert) {
      @block("no-boundary-block")
      class NoBoundaryBlock extends Component {
        <template>
          <div class="no-boundary-content">Content</div>
        </template>
      }

      debugHooks.setCallback(DEBUG_CALLBACK.OUTLET_INFO_COMPONENT, () => null);

      withPluginApi((api) =>
        api.renderBlocks("sidebar-blocks", [{ block: NoBoundaryBlock }])
      );

      await render(<template><BlockOutlet @name="sidebar-blocks" /></template>);

      assert
        .dom(".block-outlet-debug")
        .doesNotExist("debug boundary not shown");
      assert.dom(".no-boundary-content").exists("content renders normally");
    });

    test("debugHooks.setCallback(OUTLET_INFO_COMPONENT) can be cleared by setting to null", async function (assert) {
      @block("boundary-clear-block")
      class BoundaryClearBlock extends Component {
        <template>
          <div class="boundary-clear-content">Content</div>
        </template>
      }

      debugHooks.setCallback(
        DEBUG_CALLBACK.OUTLET_INFO_COMPONENT,
        () => MockOutletInfo
      );
      debugHooks.setCallback(DEBUG_CALLBACK.OUTLET_INFO_COMPONENT, null);

      withPluginApi((api) =>
        api.renderBlocks("hero-blocks", [{ block: BoundaryClearBlock }])
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

      // Counter to generate unique IDs for each group at each depth
      let idCounter = 0;

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
            id: `level-${depth}-${idCounter++}`,
            children: buildNestedConfig(depth + 1, maxDepth),
          },
          {
            block: BlockGroup,
            id: `level-${depth}-${idCounter++}`,
            children: buildNestedConfig(depth + 1, maxDepth),
          },
        ];
      };

      withPluginApi((api) =>
        api.renderBlocks("homepage-blocks", buildNestedConfig(0, 5))
      );

      await render(
        <template><BlockOutlet @name="homepage-blocks" /></template>
      );

      assert.dom(".homepage-blocks").exists("outlet renders");

      assert.dom('[data-block-id^="level-0"]').exists("level 0 groups exist");
      assert.dom('[data-block-id^="level-1"]').exists("level 1 groups exist");
      assert.dom('[data-block-id^="level-2"]').exists("level 2 groups exist");
      assert.dom('[data-block-id^="level-3"]').exists("level 3 groups exist");
      assert.dom('[data-block-id^="level-4"]').exists("level 4 groups exist");

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

      const buildDeeplyNestedConfig = (depth) => {
        if (depth <= 0) {
          return [{ block: DeepLeafBlock }];
        }

        return [
          {
            block: BlockGroup,
            id: `deep-${depth}`,
            children: buildDeeplyNestedConfig(depth - 1),
          },
        ];
      };

      withPluginApi((api) =>
        api.renderBlocks("sidebar-blocks", buildDeeplyNestedConfig(10))
      );

      await render(<template><BlockOutlet @name="sidebar-blocks" /></template>);

      assert.dom(".sidebar-blocks").exists("outlet renders");

      assert
        .dom(".sidebar-blocks__block-container--deep-10")
        .exists("deepest group exists");
      assert
        .dom(".sidebar-blocks__block-container--deep-1")
        .exists("shallowest group exists");
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

      withPluginApi((api) =>
        api.renderBlocks("main-outlet-blocks", [
          {
            block: BlockGroup,
            id: "outer",
            children: [
              {
                block: BlockGroup,
                id: "middle-1",
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
                id: "middle-2",
                conditions: { type: "user", loggedIn: false },
                children: [{ block: ConditionalLeaf, args: { level: "3c" } }],
              },
            ],
          },
        ])
      );

      await render(
        <template><BlockOutlet @name="main-outlet-blocks" /></template>
      );

      assert
        .dom(".main-outlet-blocks__block-container--outer")
        .exists("outer group renders");
      assert
        .dom(".main-outlet-blocks__block-container--middle-1")
        .exists("middle-1 group renders");
      assert
        .dom('.conditional-leaf[data-level="3a"]')
        .doesNotExist("conditional leaf 3a hidden (logged out required)");
      assert
        .dom('.conditional-leaf[data-level="3b"]')
        .exists("unconditional leaf 3b renders");
      assert
        .dom(".main-outlet-blocks__block-container--middle-2")
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

      withTestBlockRegistration(() => registerBlock(StringRefBlock));
      withPluginApi((api) =>
        api.renderBlocks("homepage-blocks", [{ block: "string-ref-block" }])
      );

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

      withTestBlockRegistration(() => registerBlock(StringArgsBlock));
      withPluginApi((api) =>
        api.renderBlocks("hero-blocks", [
          { block: "string-args-block", args: { title: "Hello", count: 42 } },
        ])
      );

      await render(<template><BlockOutlet @name="hero-blocks" /></template>);

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
        registerBlock(ClassRefBlock);
        registerBlock(StringMixedBlock);
      });

      withPluginApi((api) =>
        api.renderBlocks("hero-blocks", [
          { block: ClassRefBlock },
          { block: "string-mixed-block" },
        ])
      );

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

      withTestBlockRegistration(() => registerBlock(NestedStringBlock));

      withPluginApi((api) =>
        api.renderBlocks("main-outlet-blocks", [
          {
            block: BlockGroup,
            id: "container",
            children: [{ block: "nested-string-block" }],
          },
        ])
      );

      await render(
        <template><BlockOutlet @name="main-outlet-blocks" /></template>
      );

      assert
        .dom(".main-outlet-blocks__block-container--container")
        .exists("container renders");
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
        registerBlockFactory(
          "factory-render-block",
          async () => FactoryRenderBlock
        )
      );
      withPluginApi((api) =>
        api.renderBlocks("sidebar-blocks", [{ block: "factory-render-block" }])
      );

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
        registerBlockFactory("default-export-block", async () => ({
          default: DefaultExportBlock,
        }))
      );
      withPluginApi((api) =>
        api.renderBlocks("hero-blocks", [{ block: "default-export-block" }])
      );

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

      // Configure with one required block and one optional missing block
      withPluginApi((api) =>
        api.renderBlocks("hero-blocks", [
          { block: RequiredBlock },
          { block: "non-existent-block?" }, // Optional - should silently skip
        ])
      );

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

      withTestBlockRegistration(() => registerBlock(PresentOptionalBlock));

      withPluginApi((api) =>
        api.renderBlocks("sidebar-blocks", [
          { block: "present-optional-block?" }, // Optional but present
        ])
      );

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

      withTestBlockRegistration(() => registerBlock(MixOptionalPresent));

      withPluginApi((api) =>
        api.renderBlocks("main-outlet-blocks", [
          { block: MixRequiredBlock },
          { block: "missing-optional-block?" }, // Optional missing - skipped
          { block: "mix-optional-present?" }, // Optional present - rendered
        ])
      );

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

      withPluginApi((api) =>
        api.renderBlocks("homepage-blocks", [
          { block: "missing-1?" },
          { block: "missing-2?" },
          { block: SingleRequired },
          { block: "missing-3?" },
        ])
      );

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

      withTestBlockRegistration(() => registerBlock(OptionalWidget));

      withPluginApi((api) =>
        api.renderBlocks("hero-blocks", [
          { block: "chat:optional-widget?" }, // Present namespaced optional
          { block: "chat:missing-widget?" }, // Missing namespaced optional
        ])
      );

      await render(<template><BlockOutlet @name="hero-blocks" /></template>);

      assert.dom(".hero-blocks").exists("outlet renders");
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

      debugHooks.setCallback(DEBUG_CALLBACK.GHOST_BLOCKS, () => true);
      debugHooks.setCallback(
        DEBUG_CALLBACK.BLOCK_DEBUG,
        (blockData, context) => {
          if (blockData.failureType === FAILURE_TYPE.OPTIONAL_MISSING) {
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

      withPluginApi((api) =>
        api.renderBlocks("sidebar-blocks", [
          { block: GhostTestBlock },
          { block: "missing-optional-block?", args: { foo: "bar" } },
        ])
      );

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
      assert.strictEqual(
        ghostBlockData.failureType,
        FAILURE_TYPE.OPTIONAL_MISSING,
        "ghost receives failureType OPTIONAL_MISSING"
      );
      assert.deepEqual(
        ghostBlockData.args,
        { foo: "bar" },
        "ghost receives original args"
      );
      // The forwarded key must be the canonical `${name}:${__stableKey}` shape
      // (no categorising prefix) so consumers can correlate the ghost back to
      // its layout entry.
      assert.true(
        /^missing-optional-block:\d+$/.test(ghostBlockData.key),
        `optional-missing key is "name:stableKey" with no prefix (got "${ghostBlockData.key}")`
      );
    });

    test("unknown-block ghost key forwarded to BLOCK_DEBUG matches the entry's stable key (no internal prefix)", async function (assert) {
      // A rendered ghost is correlated back to its layout entry by the
      // forwarded `key`, which must be the same `${name}:${__stableKey}` shape
      // resolved blocks expose — otherwise lookups (selection, removal) miss.
      let ghostKey;

      debugHooks.setCallback(DEBUG_CALLBACK.GHOST_BLOCKS, () => true);
      debugHooks.setCallback(DEBUG_CALLBACK.BLOCK_DEBUG, (blockData) => {
        if (blockData.failureType === FAILURE_TYPE.UNKNOWN_BLOCK) {
          ghostKey = blockData.key;
          return {
            Component: <template>
              <div class="ghost-block" data-name={{blockData.name}}></div>
            </template>,
          };
        }
        return { Component: blockData.Component };
      });

      // A truly-unregistered block only survives layout registration on the
      // permissive session-draft layer (the in-session editing path); the
      // strict `api.renderBlocks` path would reject it outright.
      _setLayoutLayer(
        "sidebar-blocks",
        LAYOUT_LAYERS.SESSION_DRAFT,
        [{ block: "totally-unregistered-block" }],
        getOwner(this),
        { permissive: true }
      );

      await render(<template><BlockOutlet @name="sidebar-blocks" /></template>);

      assert.true(
        /^totally-unregistered-block:\d+$/.test(ghostKey),
        `unknown-block key is "name:stableKey" with no prefix (got "${ghostKey}")`
      );
    });

    test("unknown container forwards its children to GHOST_CHILDREN_CREATOR", async function (assert) {
      // An unregistered container's nested blocks must stay visible (and
      // editable) so the author can salvage them before removing the broken
      // parent. Core kicks this off by invoking GHOST_CHILDREN_CREATOR with
      // the entry's children, mirroring the resolved-container path.
      let creatorArgs = null;
      let forwardedChildren = null;

      debugHooks.setCallback(DEBUG_CALLBACK.GHOST_BLOCKS, () => true);
      debugHooks.setCallback(
        DEBUG_CALLBACK.GHOST_CHILDREN_CREATOR,
        (...args) => {
          creatorArgs = args;
          return [
            {
              key: "child-sentinel:0",
              Component: <template>
                <div class="ghost-child-sentinel"></div>
              </template>,
            },
          ];
        }
      );
      debugHooks.setCallback(DEBUG_CALLBACK.BLOCK_DEBUG, (blockData) => {
        if (blockData.failureType === FAILURE_TYPE.UNKNOWN_BLOCK) {
          forwardedChildren = blockData.children;
          const kids = blockData.children ?? [];
          return {
            Component: <template>
              <div class="ghost-block" data-name={{blockData.name}}>
                {{#each kids key="key" as |child|}}
                  <child.Component />
                {{/each}}
              </div>
            </template>,
          };
        }
        return { Component: blockData.Component };
      });

      // Unknown blocks only survive registration on the permissive
      // session-draft layer; strict `api.renderBlocks` rejects them.
      _setLayoutLayer(
        "sidebar-blocks",
        LAYOUT_LAYERS.SESSION_DRAFT,
        [
          {
            block: "unregistered-container",
            children: [
              { block: "unregistered-child" },
              { block: "unregistered-child" },
            ],
          },
        ],
        getOwner(this),
        { permissive: true }
      );

      await render(<template><BlockOutlet @name="sidebar-blocks" /></template>);

      assert
        .dom('.ghost-block[data-name="unregistered-container"]')
        .exists("the unknown container renders as a ghost");
      assert.notStrictEqual(
        creatorArgs,
        null,
        "GHOST_CHILDREN_CREATOR was invoked for the unknown container"
      );
      assert.strictEqual(
        creatorArgs[0].length,
        2,
        "the container's two child entries are forwarded as the first arg"
      );
      assert.strictEqual(
        creatorArgs[2],
        "sidebar-blocks/unregistered-container[0]",
        "the container path is forwarded as the third arg"
      );
      assert.strictEqual(
        typeof creatorArgs[5],
        "function",
        "the block resolver is forwarded as the sixth arg"
      );
      assert.strictEqual(
        forwardedChildren.length,
        1,
        "the creator's return value is forwarded as blockData.children"
      );
      assert
        .dom(".ghost-child-sentinel")
        .exists("the forwarded ghost children render inside the container");
    });

    test("unknown container renders a childless ghost when no GHOST_CHILDREN_CREATOR is registered", async function (assert) {
      // Core-only installs (no creator registered) must degrade to the
      // previous behaviour: the container ghost still renders, just without
      // nested children.
      let forwardedChildren = "unset";

      debugHooks.setCallback(DEBUG_CALLBACK.GHOST_BLOCKS, () => true);
      debugHooks.setCallback(DEBUG_CALLBACK.BLOCK_DEBUG, (blockData) => {
        if (blockData.failureType === FAILURE_TYPE.UNKNOWN_BLOCK) {
          forwardedChildren = blockData.children;
          return {
            Component: <template>
              <div class="ghost-block" data-name={{blockData.name}}></div>
            </template>,
          };
        }
        return { Component: blockData.Component };
      });

      _setLayoutLayer(
        "sidebar-blocks",
        LAYOUT_LAYERS.SESSION_DRAFT,
        [
          {
            block: "unregistered-container",
            children: [{ block: "unregistered-child" }],
          },
        ],
        getOwner(this),
        { permissive: true }
      );

      await render(<template><BlockOutlet @name="sidebar-blocks" /></template>);

      assert
        .dom('.ghost-block[data-name="unregistered-container"]')
        .exists("the unknown container still renders as a ghost");
      assert.strictEqual(
        forwardedChildren,
        undefined,
        "no children are forwarded when no creator is registered"
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

      withPluginApi((api) =>
        api.renderBlocks("homepage-blocks", [
          { block: OutletArgsTestBlock, args: { title: "Hello", count: 42 } },
        ])
      );

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

      withPluginApi((api) =>
        api.renderBlocks("sidebar-blocks", [
          {
            block: BlockGroup,

            children: [{ block: GroupChildBlock }],
          },
        ])
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

      withPluginApi((api) =>
        api.renderBlocks("hero-blocks", [
          {
            block: BlockGroup,

            children: [
              {
                block: BlockGroup,

                children: [{ block: DeepNestedBlock }],
              },
            ],
          },
        ])
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

      withPluginApi((api) =>
        api.renderBlocks("main-outlet-blocks", [
          {
            block: ConditionalBlock,
            conditions: {
              type: "outlet-arg",
              path: "topic.closed",
              value: true,
            },
          },
        ])
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
        .exists("block renders when outlet-arg condition passes");
    });

    test("outlet args condition can fail", async function (assert) {
      @block("failing-condition-block")
      class FailingConditionBlock extends Component {
        <template>
          <div class="failing-condition-content">Should not render</div>
        </template>
      }

      withPluginApi((api) =>
        api.renderBlocks("hero-blocks", [
          {
            block: FailingConditionBlock,
            conditions: {
              type: "outlet-arg",
              path: "topic.closed",
              value: true,
            },
          },
        ])
      );

      // Condition should fail - topic is not closed
      const openTopicArgs = { topic: { closed: false } };
      await render(
        <template>
          <BlockOutlet @name="hero-blocks" @outletArgs={{openTopicArgs}} />
        </template>
      );

      assert
        .dom(".failing-condition-content")
        .doesNotExist("block does not render when outlet-arg condition fails");
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

      withPluginApi((api) =>
        api.renderBlocks("sidebar-blocks", [{ block: DebugOutletArgsBlock }])
      );

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
      const stub = sinon.stub(console, "error");
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

      withPluginApi((api) =>
        api.renderBlocks("homepage-blocks", [
          { block: SafeBlock },
          { block: ThrowingBlock },
        ])
      );

      await render(
        <template><BlockOutlet @name="homepage-blocks" /></template>
      );

      assert.notStrictEqual(errorCaught, null, "error was caught");
      assert.true(
        errorCaught?.message?.includes("Block render error"),
        "error message is correct"
      );
      assert.true(stub.calledWithMatch("Error occurred:"));

      stub.restore();
    });

    test("block with invalid condition type shows warning in dev mode", async function (assert) {
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

      withPluginApi((api) =>
        api.renderBlocks("sidebar-blocks", [
          { block: NullConditionsBlock, conditions: null },
        ])
      );

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

      withPluginApi((api) =>
        api.renderBlocks("hero-blocks", [
          { block: UndefinedConditionsBlock, conditions: undefined },
        ])
      );

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

      // The validation promise rejects when conditions are invalid.
      // In tests, unhandled promise rejections cause test failures.
      // We can access the validation promise via the internal outletLayouts.
      withPluginApi((api) =>
        api.renderBlocks("main-outlet-blocks", [
          {
            block: ValidationErrorBlock,
            conditions: { type: "outlet-arg" }, // missing required "path"
          },
        ])
      );

      // Access the validation promise to catch the expected error
      const layoutData = _getOutletLayouts().get("main-outlet-blocks");

      await assert.rejects(
        layoutData.validatedLayout,
        /missing required arg "path"/,
        "validation error thrown for missing required path argument"
      );
    });
  });

  module("instance survival across structural edits", function () {
    // Appends `entry` to an outlet's session-draft layer, reusing the existing
    // wrapped entries by reference — the same identity-preserving shape a
    // structural insert produces. `_setLayoutLayer` mints a stable key for the
    // new entry and leaves the existing keys untouched (skipExisting), so this
    // mirrors inserting a sibling without disturbing the rest of the tree.
    function appendSibling(outletName, currentLayout, entry, owner) {
      const next = [...currentLayout, entry];
      _setLayoutLayer(outletName, LAYOUT_LAYERS.SESSION_DRAFT, next, owner, {
        permissive: true,
      });
      return next;
    }

    test("a child inserted into an initially-empty container renders", async function (assert) {
      // A container first rendered with zero children must still pick up its
      // first child on a later edit. The cached container reads its children
      // through a tracked holder; if the holder is only created for containers
      // that start non-empty, an empty container freezes on its empty state and
      // never shows anything inserted into it (the "drag the first block into an
      // empty section" flow).
      @block("late-child")
      class LateChild extends Component {
        <template>
          <div class="late-child">Late</div>
        </template>
      }

      const owner = getOwner(this);
      const container = { block: BlockGroup, children: [] };
      _setLayoutLayer(
        "main-outlet-blocks",
        LAYOUT_LAYERS.SESSION_DRAFT,
        [container],
        owner,
        { permissive: true }
      );

      await render(
        <template><BlockOutlet @name="main-outlet-blocks" /></template>
      );
      assert
        .dom(".late-child")
        .doesNotExist("the empty container starts with no children");

      // Insert the first child into the (previously empty) container.
      container.children = [{ block: LateChild }];
      _setLayoutLayer(
        "main-outlet-blocks",
        LAYOUT_LAYERS.SESSION_DRAFT,
        [container],
        owner,
        { permissive: true }
      );
      await settled();

      assert
        .dom(".late-child")
        .exists("the child inserted into the empty container renders");
    });

    test("a leaf inside a container survives an unrelated sibling insert", async function (assert) {
      // The core regression: leaf blocks are already cached, but they live
      // inside containers. When a container is re-curried on every render, its
      // children remount even though nothing about them changed. Inserting an
      // unrelated sibling at the root must not tear down a leaf nested in a
      // pre-existing container.
      @block("survivor-leaf")
      class SurvivorLeaf extends Component {
        <template>
          <div class="survivor-leaf">Leaf</div>
        </template>
      }

      @block("late-leaf")
      class LateLeaf extends Component {
        <template>
          <div class="late-leaf">Late</div>
        </template>
      }

      const owner = getOwner(this);
      const layout = [
        { block: BlockGroup, children: [{ block: SurvivorLeaf }] },
      ];
      _setLayoutLayer(
        "hero-blocks",
        LAYOUT_LAYERS.SESSION_DRAFT,
        layout,
        owner,
        {
          permissive: true,
        }
      );

      await render(<template><BlockOutlet @name="hero-blocks" /></template>);

      const before = find(".survivor-leaf");
      assert.dom(before).exists("the nested leaf renders initially");

      appendSibling("hero-blocks", layout, { block: LateLeaf }, owner);
      await settled();

      assert.dom(".late-leaf").exists("the inserted sibling renders");
      assert.strictEqual(
        find(".survivor-leaf"),
        before,
        "the nested leaf keeps its DOM node (not remounted) after the insert"
      );
    });

    test("an async-data block inside a container is built once across an unrelated insert", async function (assert) {
      // Encodes the user-visible symptom: data-loading blocks re-fetch and
      // shift layout when an unrelated block is inserted, because their
      // container remounts them. Construction (where such blocks kick off their
      // load) must happen exactly once.
      let constructCount = 0;

      @block("counting-leaf")
      class CountingLeaf extends Component {
        constructor() {
          super(...arguments);
          constructCount++;
        }

        <template>
          <div class="counting-leaf">Counting</div>
        </template>
      }

      @block("other-late-leaf")
      class OtherLateLeaf extends Component {
        <template>
          <div class="other-late-leaf">Other</div>
        </template>
      }

      const owner = getOwner(this);
      const layout = [
        { block: BlockGroup, children: [{ block: CountingLeaf }] },
      ];
      _setLayoutLayer(
        "sidebar-blocks",
        LAYOUT_LAYERS.SESSION_DRAFT,
        layout,
        owner,
        { permissive: true }
      );

      await render(<template><BlockOutlet @name="sidebar-blocks" /></template>);
      assert.strictEqual(constructCount, 1, "constructed once on first render");

      appendSibling("sidebar-blocks", layout, { block: OtherLateLeaf }, owner);
      await settled();

      assert.strictEqual(
        constructCount,
        1,
        "not reconstructed when an unrelated sibling is inserted"
      );
    });

    test("two consecutive inserts into the same container both render", async function (assert) {
      // Guards the load-bearing invariant: a cache hit must reuse the *same*
      // children holder instance, so the second insert is observed too (a stale
      // holder would freeze the container's children after the first edit).
      @block("base-child")
      class BaseChild extends Component {
        <template>
          <div class="base-child">Base</div>
        </template>
      }

      @block("first-added")
      class FirstAdded extends Component {
        <template>
          <div class="first-added">First</div>
        </template>
      }

      @block("second-added")
      class SecondAdded extends Component {
        <template>
          <div class="second-added">Second</div>
        </template>
      }

      const owner = getOwner(this);
      // A single container whose children array we grow twice. Each republish
      // reuses the container entry by reference (identity preserved) but swaps
      // in a fresh children array — exactly what an "insert inside" produces.
      const container = { block: BlockGroup, children: [{ block: BaseChild }] };
      _setLayoutLayer(
        "main-outlet-blocks",
        LAYOUT_LAYERS.SESSION_DRAFT,
        [container],
        owner,
        { permissive: true }
      );

      await render(
        <template><BlockOutlet @name="main-outlet-blocks" /></template>
      );
      assert.dom(".base-child").exists("the base child renders");

      // First insert into the container.
      container.children = [...container.children, { block: FirstAdded }];
      _setLayoutLayer(
        "main-outlet-blocks",
        LAYOUT_LAYERS.SESSION_DRAFT,
        [container],
        owner,
        { permissive: true }
      );
      await settled();
      assert.dom(".first-added").exists("the first inserted child renders");

      // Second insert into the same container.
      container.children = [...container.children, { block: SecondAdded }];
      _setLayoutLayer(
        "main-outlet-blocks",
        LAYOUT_LAYERS.SESSION_DRAFT,
        [container],
        owner,
        { permissive: true }
      );
      await settled();
      assert.dom(".second-added").exists("the second inserted child renders");
      assert
        .dom(".first-added")
        .exists("the first inserted child still renders");
    });

    test("editing a container's own arg still re-renders it", async function (assert) {
      // Negative guard against over-caching: own-arg changes must still produce
      // fresh output. We toggle a container arg and assert the rendered value
      // updates even though the container instance may persist.
      @block("arg-container", {
        container: true,
        args: { label: { type: "string" } },
      })
      class ArgContainer extends Component {
        <template>
          <div class="arg-container" data-label={{@label}}>
            {{#each @children key="key" as |child|}}
              <child.Component />
            {{/each}}
          </div>
        </template>
      }

      @block("inert-child")
      class InertChild extends Component {
        <template>
          <div class="inert-child">Child</div>
        </template>
      }

      const owner = getOwner(this);
      const layout = [
        {
          block: ArgContainer,
          args: { label: "before" },
          children: [{ block: InertChild }],
        },
      ];
      _setLayoutLayer(
        "hero-blocks",
        LAYOUT_LAYERS.SESSION_DRAFT,
        layout,
        owner,
        {
          permissive: true,
        }
      );

      await render(<template><BlockOutlet @name="hero-blocks" /></template>);
      assert.dom(".arg-container").hasAttribute("data-label", "before");

      // Mutate the (tracked) entry args in place — the live arg-update path.
      layout[0].args.label = "after";
      await settled();
      assert
        .dom(".arg-container")
        .hasAttribute("data-label", "after", "own-arg update propagates");
    });

    test("a container moved under a different parent gets a fresh hierarchy", async function (assert) {
      // The cache is keyed by stable key, which a moved entry keeps — so the
      // hierarchy (baked into the curry and the debug payload) must be part of
      // the cache match, otherwise a moved container would keep a stale path.
      @block("hierarchy-probe", { container: true })
      class HierarchyProbe extends Component {
        // `__hierarchy` is a reserved arg name in templates, so read it in JS.
        get hierarchy() {
          return this.args.__hierarchy;
        }

        <template>
          <div class="hierarchy-probe" data-h={{this.hierarchy}}>
            {{#each @children key="key" as |child|}}
              <child.Component />
            {{/each}}
          </div>
        </template>
      }

      @block("probe-leaf")
      class ProbeLeaf extends Component {
        <template>
          <div class="probe-leaf">Leaf</div>
        </template>
      }

      const owner = getOwner(this);
      // `movable` is reused by reference across the republish (keeps its stable
      // key), but it changes parent — from inside the group to the outlet root.
      // The group keeps a filler child so it never becomes an empty container.
      const movable = {
        block: HierarchyProbe,
        children: [{ block: ProbeLeaf }],
      };
      const group = {
        block: BlockGroup,
        id: "g",
        children: [{ block: ProbeLeaf }, movable],
      };
      _setLayoutLayer(
        "hero-blocks",
        LAYOUT_LAYERS.SESSION_DRAFT,
        [group],
        owner,
        { permissive: true }
      );

      await render(<template><BlockOutlet @name="hero-blocks" /></template>);
      assert
        .dom(".hierarchy-probe")
        .exists("the probe renders inside the group");
      const hierarchyInGroup = find(".hierarchy-probe").getAttribute("data-h");
      assert.true(
        hierarchyInGroup.includes("group"),
        `probe hierarchy reflects the group parent (got "${hierarchyInGroup}")`
      );

      // Move the probe out to the outlet root; the group keeps its filler.
      group.children = [{ block: ProbeLeaf }];
      _setLayoutLayer(
        "hero-blocks",
        LAYOUT_LAYERS.SESSION_DRAFT,
        [movable, group],
        owner,
        { permissive: true }
      );
      await settled();

      assert
        .dom(".hierarchy-probe")
        .exists("the probe still renders at the root");
      const hierarchyAtRoot = find(".hierarchy-probe").getAttribute("data-h");
      assert.false(
        hierarchyAtRoot.includes("group"),
        `probe hierarchy no longer reflects the group (got "${hierarchyAtRoot}")`
      );
      assert.notStrictEqual(
        hierarchyAtRoot,
        hierarchyInGroup,
        "the moved container's hierarchy is recomputed, not stale"
      );
    });
  });
});
