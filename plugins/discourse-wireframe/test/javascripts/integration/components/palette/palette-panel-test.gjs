import { fillIn, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import PalettePanel from "discourse/plugins/discourse-wireframe/discourse/components/editor/palette/palette-panel";

module(
  "Integration | discourse-wireframe | Component | palette-panel",
  function (hooks) {
    setupRenderingTest(hooks);

    test("renders at least one entry per registered starter block", async function (assert) {
      await render(<template><PalettePanel /></template>);

      // The starter blocks plus any core built-ins (`head`, `group`)
      // auto-register before tests run, so the palette should have a
      // non-trivial number of entries.
      assert.dom(".wireframe-palette-entry").exists();
      const entries = document.querySelectorAll(".wireframe-palette-entry");
      assert.true(entries.length >= 8);
    });

    test("filters by the search input", async function (assert) {
      await render(<template><PalettePanel /></template>);

      await fillIn(".wireframe-palette__search", "paragraph");
      assert
        .dom(".wireframe-palette-entry")
        .exists({ count: 1 }, "only Paragraph matches 'paragraph'");
      assert.dom(".wireframe-palette-entry").hasText(/Paragraph/);
    });

    test("renders the empty state when no entries match", async function (assert) {
      await render(<template><PalettePanel /></template>);

      await fillIn(".wireframe-palette__search", "definitely-no-match");
      assert.dom(".wireframe-palette-entry").doesNotExist();
      assert.dom(".wireframe-palette .panel-empty").exists();
    });

    test("category chips render at least the namespace types we expect", async function (assert) {
      await render(<template><PalettePanel /></template>);

      // The built-in blocks now ship from core; we expect the block-author
      // category chips (Content, Layout, Navigation, Discourse data) — chip
      // labels are i18n'd for namespace keys and raw for arbitrary categories.
      const chips = [
        ...document.querySelectorAll(".wireframe-palette__chip"),
      ].map((el) => el.textContent.trim());
      assert.true(chips.includes("Content"));
      assert.true(chips.includes("Layout"));
      assert.true(chips.includes("Navigation"));
      assert.true(chips.includes("Discourse data"));
    });
  }
);
