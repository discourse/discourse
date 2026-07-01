import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import BlockThumbnail from "discourse/plugins/discourse-wireframe/discourse/components/editor/palette/block-thumbnail";

// A stand-in for a block's inline SVG thumbnail component.
const StubThumbnail = <template>
  <svg class="stub-thumbnail" ...attributes></svg>
</template>;

module(
  "Integration | discourse-wireframe | Component | block-thumbnail",
  function (hooks) {
    setupRenderingTest(hooks);

    test("renders a component thumbnail inline, forwarding the sizing class", async function (assert) {
      await render(
        <template>
          <BlockThumbnail
            @thumbnail={{StubThumbnail}}
            @icon="cube"
            class="sized"
          />
        </template>
      );

      assert
        .dom("svg.stub-thumbnail.sized")
        .exists("the component renders inline and receives the splatted class");
      assert.dom(".wireframe-block-thumbnail-default").doesNotExist();
    });

    test("renders a URL string through an image", async function (assert) {
      await render(
        <template>
          <BlockThumbnail
            @thumbnail="/uploads/heading.png"
            @icon="cube"
            class="sized"
          />
        </template>
      );

      assert.dom("img.sized").exists();
      const src = document.querySelector("img.sized").getAttribute("src");
      assert.true(
        src.includes("/uploads/heading.png"),
        "the image points at the declared URL"
      );
      assert.dom(".wireframe-block-thumbnail-default").doesNotExist();
    });

    test("renders a light/dark pair, using the light image as the default source", async function (assert) {
      const pair = { light: "/uploads/light.png", dark: "/uploads/dark.png" };

      await render(
        <template>
          <BlockThumbnail @thumbnail={{pair}} @icon="cube" class="sized" />
        </template>
      );

      assert.dom("img.sized").exists("a raster image is rendered");
      const src = document.querySelector("img.sized").getAttribute("src");
      assert.true(
        src.includes("/uploads/light.png"),
        "the light image is the default source"
      );
    });

    test("falls back to the default placeholder when nothing is declared", async function (assert) {
      await render(
        <template><BlockThumbnail @icon="cube" class="sized" /></template>
      );

      assert
        .dom(".wireframe-block-thumbnail-default.sized")
        .exists("the placeholder renders and receives the splatted class");
      assert
        .dom(".wireframe-block-thumbnail-default__icon .d-icon")
        .exists("the block's icon sits inside the placeholder frame");
    });
  }
);
