import Component from "@glimmer/component";
import { render, setupOnerror } from "@ember/test-helpers";
import { module, test } from "qunit";
import BlockOutlet, {
  block,
  renderBlocks,
} from "discourse/components/block-outlet";
import {
  _registerBlock,
  withTestBlockRegistration,
} from "discourse/lib/blocks/registration";
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
});
