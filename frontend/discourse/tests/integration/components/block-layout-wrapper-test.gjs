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

    test("data-block-id is set when id is provided", async function (assert) {
      @block("id-attr-test-block")
      class IdAttrTestBlock extends Component {
        <template>
          <div class="id-content">Content</div>
        </template>
      }

      withPluginApi((api) =>
        api.renderBlocks("hero-blocks", [
          { block: IdAttrTestBlock, id: "my-block-id" },
        ])
      );

      await render(<template><BlockOutlet @name="hero-blocks" /></template>);

      assert
        .dom('[data-block-id="my-block-id"]')
        .exists("data-block-id attribute is set");
    });

    test("data-block-id is not set when id is not provided", async function (assert) {
      @block("no-id-attr-block")
      class NoIdAttrBlock extends Component {
        <template>
          <div class="no-id-content">Content</div>
        </template>
      }

      withPluginApi((api) =>
        api.renderBlocks("hero-blocks", [{ block: NoIdAttrBlock }])
      );

      await render(<template><BlockOutlet @name="hero-blocks" /></template>);

      const wrapper = document.querySelector(".hero-blocks__block");
      assert.strictEqual(
        wrapper.getAttribute("data-block-id"),
        null,
        "data-block-id is not set when id is not provided"
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
            id: "full-test",
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
        containerWrapper.getAttribute("data-block-id"),
        "full-test",
        "container has correct data-block-id"
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
            id: "outer",
            children: [
              {
                block: BlockGroup,
                id: "inner",
                children: [{ block: NestedAttrLeaf }],
              },
            ],
          },
        ])
      );

      await render(<template><BlockOutlet @name="hero-blocks" /></template>);

      assert
        .dom('[data-block-id="outer"]')
        .exists("outer container has data-block-id");
      assert
        .dom('[data-block-id="inner"]')
        .exists("inner container has data-block-id");

      const leaf = document.querySelector(
        '[data-block-name="nested-attr-leaf"]'
      );
      assert.strictEqual(
        leaf.getAttribute("data-block-id"),
        null,
        "nested leaf without id does not have data-block-id"
      );
    });
  });

  module("CSS classes", function () {
    test("leaf blocks have {outlet}__block class", async function (assert) {
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
        .exists("leaf block has outlet__block class");
    });

    test("container blocks have {outlet}__block-container class", async function (assert) {
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
            children: [{ block: ContainerCssChild }],
          },
        ])
      );

      await render(<template><BlockOutlet @name="hero-blocks" /></template>);

      const containerWrapper = document.querySelector(
        '[data-block-name="group"]'
      );
      assert.true(
        containerWrapper.classList.contains("hero-blocks__block-container"),
        "container has outlet__block-container class"
      );
    });

    test("id generates BEM modifier class on leaf blocks", async function (assert) {
      @block("bem-modifier-block")
      class BemModifierBlock extends Component {
        <template>
          <div class="bem-content">Content</div>
        </template>
      }

      withPluginApi((api) =>
        api.renderBlocks("sidebar-blocks", [
          { block: BemModifierBlock, id: "featured" },
        ])
      );

      await render(<template><BlockOutlet @name="sidebar-blocks" /></template>);

      assert
        .dom(".sidebar-blocks__block--featured")
        .exists("leaf block has BEM modifier class from id");
    });

    test("id generates BEM modifier class on container blocks", async function (assert) {
      @block("bem-container-child")
      class BemContainerChild extends Component {
        <template>
          <div class="bem-child">Child</div>
        </template>
      }

      withPluginApi((api) =>
        api.renderBlocks("hero-blocks", [
          {
            block: BlockGroup,
            id: "main-group",
            children: [{ block: BemContainerChild }],
          },
        ])
      );

      await render(<template><BlockOutlet @name="hero-blocks" /></template>);

      assert
        .dom(".hero-blocks__block-container--main-group")
        .exists("container has BEM modifier class from id");
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
