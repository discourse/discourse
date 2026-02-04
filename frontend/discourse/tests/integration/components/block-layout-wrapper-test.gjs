import Component from "@glimmer/component";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { block } from "discourse/blocks";
import BlockOutlet from "discourse/blocks/block-outlet";
import BlockGroup from "discourse/blocks/builtin/block-group";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Blocks | BlockLayoutWrapper", function (hooks) {
  setupRenderingTest(hooks);

  module("data attributes", function () {
    test("non-container block has correct data-block-name", async function (assert) {
      @block("data-attr-test-block")
      class DataAttrTestBlock extends Component {
        <template>
          <div class="test-content">Content</div>
        </template>
      }

      withPluginApi((api) =>
        api.renderBlocks("hero-blocks", [{ block: DataAttrTestBlock }])
      );

      await render(<template><BlockOutlet @name="hero-blocks" /></template>);

      assert
        .dom('[data-block-name="data-attr-test-block"]')
        .exists("data-block-name attribute is set");
      assert
        .dom(".hero-blocks__block")
        .hasAttribute(
          "data-block-name",
          "data-attr-test-block",
          "data-block-name has correct value"
        );
    });

    test("namespaced block has correct data-block-namespace", async function (assert) {
      @block("test-plugin:namespaced-block")
      class NamespacedBlock extends Component {
        <template>
          <div class="namespaced-content">Namespaced</div>
        </template>
      }

      withPluginApi((api) =>
        api.renderBlocks("sidebar-blocks", [{ block: NamespacedBlock }])
      );

      await render(<template><BlockOutlet @name="sidebar-blocks" /></template>);

      assert
        .dom('[data-block-namespace="test-plugin"]')
        .exists("data-block-namespace attribute is set for namespaced block");
      assert
        .dom(".sidebar-blocks__block")
        .hasAttribute(
          "data-block-namespace",
          "test-plugin",
          "data-block-namespace has correct value"
        );
    });

    test("core block has no data-block-namespace", async function (assert) {
      @block("core-style-block")
      class CoreStyleBlock extends Component {
        <template>
          <div class="core-content">Core</div>
        </template>
      }

      withPluginApi((api) =>
        api.renderBlocks("hero-blocks", [{ block: CoreStyleBlock }])
      );

      await render(<template><BlockOutlet @name="hero-blocks" /></template>);

      const wrapper = document.querySelector(".hero-blocks__block");
      assert.strictEqual(
        wrapper.getAttribute("data-block-namespace"),
        null,
        "core blocks have no namespace attribute"
      );
    });

    test("container block has data-block-container='true'", async function (assert) {
      @block("container-attr-child")
      class ContainerAttrChild extends Component {
        <template>
          <div class="container-child">Child</div>
        </template>
      }

      withPluginApi((api) =>
        api.renderBlocks("homepage-blocks", [
          {
            block: BlockGroup,
            args: { name: "test-container" },
            children: [{ block: ContainerAttrChild }],
          },
        ])
      );

      await render(
        <template><BlockOutlet @name="homepage-blocks" /></template>
      );

      assert
        .dom('[data-block-container="true"]')
        .exists("container block has data-block-container attribute");
      assert
        .dom('[data-block-name="group"]')
        .hasAttribute(
          "data-block-container",
          "true",
          "container has data-block-container='true'"
        );
    });

    test("non-container block does not have data-block-container", async function (assert) {
      @block("non-container-attr-block")
      class NonContainerAttrBlock extends Component {
        <template>
          <div class="non-container-content">Leaf</div>
        </template>
      }

      withPluginApi((api) =>
        api.renderBlocks("sidebar-blocks", [{ block: NonContainerAttrBlock }])
      );

      await render(<template><BlockOutlet @name="sidebar-blocks" /></template>);

      const wrapper = document.querySelector(".sidebar-blocks__block");
      assert.strictEqual(
        wrapper.getAttribute("data-block-container"),
        null,
        "non-container blocks do not have data-block-container attribute"
      );
    });

    test("all data attributes are present on container block", async function (assert) {
      @block("full-attr-child")
      class FullAttrChild extends Component {
        <template>
          <div class="full-child">Child</div>
        </template>
      }

      withPluginApi((api) =>
        api.renderBlocks("main-outlet-blocks", [
          {
            block: BlockGroup,
            args: { name: "full-test" },
            children: [{ block: FullAttrChild }],
          },
        ])
      );

      await render(
        <template><BlockOutlet @name="main-outlet-blocks" /></template>
      );

      const containerWrapper = document.querySelector(
        '[data-block-name="group"]'
      );
      assert.strictEqual(
        containerWrapper.getAttribute("data-block-name"),
        "group",
        "container has correct data-block-name"
      );
      assert.strictEqual(
        containerWrapper.getAttribute("data-block-namespace"),
        null,
        "built-in container has no namespace"
      );
      assert.strictEqual(
        containerWrapper.getAttribute("data-block-container"),
        "true",
        "container has data-block-container='true'"
      );
    });

    test("nested blocks have correct data attributes", async function (assert) {
      @block("nested-attr-leaf")
      class NestedAttrLeaf extends Component {
        <template>
          <div class="nested-leaf">Leaf</div>
        </template>
      }

      withPluginApi((api) =>
        api.renderBlocks("hero-blocks", [
          {
            block: BlockGroup,
            args: { name: "outer" },
            children: [
              {
                block: BlockGroup,
                args: { name: "inner" },
                children: [{ block: NestedAttrLeaf }],
              },
            ],
          },
        ])
      );

      await render(<template><BlockOutlet @name="hero-blocks" /></template>);

      const containers = document.querySelectorAll(
        '[data-block-container="true"]'
      );
      assert.strictEqual(
        containers.length,
        2,
        "both nested containers have attribute"
      );

      const leaf = document.querySelector(
        '[data-block-name="nested-attr-leaf"]'
      );
      assert.strictEqual(
        leaf.getAttribute("data-block-container"),
        null,
        "nested leaf does not have container attribute"
      );
    });
  });

  module("CSS classes", function () {
    test("all blocks have {outlet}__block class", async function (assert) {
      @block("css-class-block")
      class CssClassBlock extends Component {
        <template>
          <div class="css-content">Content</div>
        </template>
      }

      withPluginApi((api) =>
        api.renderBlocks("sidebar-blocks", [{ block: CssClassBlock }])
      );

      await render(<template><BlockOutlet @name="sidebar-blocks" /></template>);

      assert
        .dom(".sidebar-blocks__block")
        .exists("block has outlet__block class");
    });

    test("container blocks also have {outlet}__block class", async function (assert) {
      @block("container-css-child")
      class ContainerCssChild extends Component {
        <template>
          <div class="container-css-content">Child</div>
        </template>
      }

      withPluginApi((api) =>
        api.renderBlocks("hero-blocks", [
          {
            block: BlockGroup,
            args: { name: "css-test" },
            children: [{ block: ContainerCssChild }],
          },
        ])
      );

      await render(<template><BlockOutlet @name="hero-blocks" /></template>);

      const containerWrapper = document.querySelector(
        '[data-block-name="group"]'
      );
      assert.true(
        containerWrapper.classList.contains("hero-blocks__block"),
        "container has outlet__block class"
      );
    });

    test("decorator classNames are applied", async function (assert) {
      @block("decorator-class-block", {
        classNames: "custom-decorator-class",
      })
      class DecoratorClassBlock extends Component {
        <template>
          <div class="decorator-content">Content</div>
        </template>
      }

      withPluginApi((api) =>
        api.renderBlocks("homepage-blocks", [{ block: DecoratorClassBlock }])
      );

      await render(
        <template><BlockOutlet @name="homepage-blocks" /></template>
      );

      assert
        .dom(".custom-decorator-class")
        .exists("decorator classNames are applied to wrapper");
    });

    test("layout entry classNames are applied", async function (assert) {
      @block("entry-class-block")
      class EntryClassBlock extends Component {
        <template>
          <div class="entry-content">Content</div>
        </template>
      }

      withPluginApi((api) =>
        api.renderBlocks("sidebar-blocks", [
          { block: EntryClassBlock, classNames: "custom-entry-class" },
        ])
      );

      await render(<template><BlockOutlet @name="sidebar-blocks" /></template>);

      assert
        .dom(".custom-entry-class")
        .exists("layout entry classNames are applied to wrapper");
    });

    test("both decorator and entry classNames are applied", async function (assert) {
      @block("both-classes-block", {
        classNames: "from-decorator",
      })
      class BothClassesBlock extends Component {
        <template>
          <div class="both-content">Content</div>
        </template>
      }

      withPluginApi((api) =>
        api.renderBlocks("main-outlet-blocks", [
          { block: BothClassesBlock, classNames: "from-entry" },
        ])
      );

      await render(
        <template><BlockOutlet @name="main-outlet-blocks" /></template>
      );

      const wrapper = document.querySelector(".main-outlet-blocks__block");
      assert.true(
        wrapper.classList.contains("from-decorator"),
        "decorator class is applied"
      );
      assert.true(
        wrapper.classList.contains("from-entry"),
        "entry class is applied"
      );
    });
  });
});
