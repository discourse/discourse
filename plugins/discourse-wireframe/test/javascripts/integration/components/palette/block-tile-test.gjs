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

    test("renders the icon without a thumbnail, the image with one", async function (assert) {
      await render(<template><BlockTile @entry={{ENTRY}} /></template>);
      assert.dom(".wireframe-block-tile__icon").exists();
      assert.dom(".wireframe-block-tile__thumbnail").doesNotExist();

      const withThumbnail = { ...ENTRY, thumbnail: "/uploads/heading.png" };
      await render(<template><BlockTile @entry={{withThumbnail}} /></template>);
      assert
        .dom(".wireframe-block-tile__thumbnail")
        .hasAttribute("src", "/uploads/heading.png");
      assert.dom(".wireframe-block-tile__icon").doesNotExist();
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
