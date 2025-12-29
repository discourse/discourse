import Component from "@glimmer/component";
import { render, setupOnerror } from "@ember/test-helpers";
import { module, test } from "qunit";
import BlockOutlet, {
  block,
  renderBlocks,
} from "discourse/components/block-outlet";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Blocks | BlockOutlet", function (hooks) {
  setupRenderingTest(hooks);

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

      renderBlocks("header-blocks", [
        { block: ArgsTestBlock, args: { title: "Hello", count: 42 } },
      ]);

      await render(<template><BlockOutlet @name="header-blocks" /></template>);

      assert.dom(".args-test .title").hasText("Hello");
      assert.dom(".args-test .count").hasText("42");
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
});
