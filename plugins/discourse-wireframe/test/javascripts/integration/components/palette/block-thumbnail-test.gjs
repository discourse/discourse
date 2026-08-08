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

    test("delegates a declared thumbnail to the core renderer", async function (assert) {
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
        .exists(
          "the core renderer renders the component and receives the class"
        );
      assert.dom(".wireframe-block-thumbnail-default").doesNotExist();
    });

    test("supplies the framed placeholder when nothing is declared", async function (assert) {
      // The wrapper's whole job: inject the palette's framed placeholder as the
      // core renderer's fallback, so an undeclared thumbnail still reads as a
      // designed tile carrying the block's icon.
      await render(
        <template><BlockThumbnail @icon="cube" class="sized" /></template>
      );

      assert
        .dom(".wireframe-block-thumbnail-default.sized")
        .exists(
          "the framed placeholder renders and receives the splatted class"
        );
      assert
        .dom(".wireframe-block-thumbnail-default__icon .d-icon")
        .exists("the block's icon sits inside the placeholder frame");
    });
  }
);
