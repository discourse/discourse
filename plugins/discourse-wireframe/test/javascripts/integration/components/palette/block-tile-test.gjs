import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import BlockTile from "discourse/plugins/discourse-wireframe/discourse/components/editor/palette/block-tile";

const ENTRY = {
  name: "heading",
  displayName: "Heading",
  icon: "heading",
  description: "A section title.",
  thumbnail: null,
};

// A stand-in for a block's inline SVG thumbnail component.
const StubThumbnail = <template>
  <svg class="stub-thumbnail" ...attributes></svg>
</template>;

module(
  "Integration | discourse-wireframe | Component | block-tile",
  function (hooks) {
    setupRenderingTest(hooks);

    test("names the tile by displayName and exposes the description via aria-describedby", async function (assert) {
      await render(<template><BlockTile @entry={{ENTRY}} /></template>);

      assert.dom(".wireframe-block-tile").hasAttribute("role", "option");
      assert
        .dom(".wireframe-block-tile")
        .hasAttribute(
          "aria-label",
          "Heading",
          "accessible name is the display name"
        );
      assert.dom(".wireframe-block-tile__label").hasText("Heading");

      const describedBy = document
        .querySelector(".wireframe-block-tile")
        .getAttribute("aria-describedby");
      assert
        .dom(`#${describedBy}`)
        .hasText(
          "A section title.",
          "the description is reachable for assistive tech, not the visible label"
        );
    });

    test("falls back to the default placeholder (framed icon) without a thumbnail", async function (assert) {
      await render(<template><BlockTile @entry={{ENTRY}} /></template>);
      assert
        .dom(
          ".wireframe-block-tile__thumbnail.wireframe-block-thumbnail-default"
        )
        .exists("renders the default placeholder as the thumbnail");
      assert
        .dom(".wireframe-block-thumbnail-default__icon .d-icon")
        .exists("the block's icon sits inside the placeholder frame");
      assert.dom("svg.stub-thumbnail").doesNotExist();
    });

    test("renders a component thumbnail inline", async function (assert) {
      const withThumbnail = { ...ENTRY, thumbnail: StubThumbnail };
      await render(<template><BlockTile @entry={{withThumbnail}} /></template>);
      assert
        .dom("svg.stub-thumbnail.wireframe-block-tile__thumbnail")
        .exists(
          "the thumbnail component renders inline and takes the sizing class"
        );
      assert.dom(".wireframe-block-thumbnail-default").doesNotExist();
    });

    test("click activates with the entry", async function (assert) {
      let picked = null;
      const onActivate = (entry) => (picked = entry);

      await render(
        <template>
          <BlockTile @entry={{ENTRY}} @onActivate={{onActivate}} />
        </template>
      );
      await click(".wireframe-block-tile");

      assert.strictEqual(picked, ENTRY, "fires onActivate with the row");
    });
  }
);
