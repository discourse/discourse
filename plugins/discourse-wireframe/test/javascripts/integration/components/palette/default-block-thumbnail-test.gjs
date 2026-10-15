import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DefaultBlockThumbnail from "discourse/plugins/discourse-wireframe/discourse/components/editor/palette/default-block-thumbnail";

module(
  "Integration | discourse-wireframe | Component | default-block-thumbnail",
  function (hooks) {
    setupRenderingTest(hooks);

    test("renders the frame and the passed icon", async function (assert) {
      await render(<template><DefaultBlockThumbnail @icon="star" /></template>);

      assert
        .dom(".wireframe-block-thumbnail-default__frame")
        .exists("renders the inline SVG frame");
      assert
        .dom(".wireframe-block-thumbnail-default__icon .d-icon.d-icon-star")
        .exists("centers the block's own icon in the frame");
    });
  }
);
