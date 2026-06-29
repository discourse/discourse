import { getOwner } from "@ember/owner";
import { click, render, settled, waitFor } from "@ember/test-helpers";
import { module, test } from "qunit";
import { _renderBlocks } from "discourse/blocks/block-outlet";
import Carousel from "discourse/blocks/builtin/carousel";
import Heading from "discourse/blocks/builtin/heading";
import Layout from "discourse/blocks/builtin/layout";
import Section from "discourse/blocks/builtin/section";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { logIn } from "discourse/tests/helpers/qunit-helpers";
import OutlinePanel from "discourse/plugins/discourse-wireframe/discourse/components/editor/outline-panel";
import { setupBlockLayoutDraftsStub } from "../../helpers/stub-block-layout-drafts";

function headings(count) {
  return Array.from({ length: count }, (_, i) => ({
    block: Heading,
    args: { text: `H${i + 1}` },
  }));
}

// Builds the editor session with a `section` container holding `count`
// children in `homepage-blocks`, then mounts the outline. The session's root
// `layout` wraps the section, so the section itself is a depth-0 container row
// whose `childCount` drives the compaction. (A top-level `layout` would instead
// become the outlet root and not render a row of its own.)
async function setupOutline(owner, count) {
  await _renderBlocks(
    "homepage-blocks",
    [{ block: Section, args: {}, children: headings(count) }],
    owner
  );
  const editor = owner.lookup("service:wireframe-workspace");
  editor.siteSettings.wireframe_enabled = true;
  logIn(owner);
  editor.enter();
  return editor;
}

// Builds the session with `count` top-level headings, so the outline shows
// `count` sibling depth-0 rows to multi-select between.
async function setupSiblings(owner, count) {
  await _renderBlocks("homepage-blocks", headings(count), owner);
  const editor = owner.lookup("service:wireframe-workspace");
  editor.siteSettings.wireframe_enabled = true;
  logIn(owner);
  editor.enter();
  return editor;
}

function selectedRows() {
  return [...document.querySelectorAll(".outline-block")].filter((row) =>
    row.classList.contains("--selected")
  );
}

module(
  "Integration | discourse-wireframe | Component | outline-panel",
  function (hooks) {
    setupRenderingTest(hooks);
    setupBlockLayoutDraftsStub(hooks);

    hooks.afterEach(function () {
      getOwner(this).lookup("service:wireframe-workspace").exit();
    });

    test("auto-collapses a container past the threshold and shows a count badge", async function (assert) {
      await setupOutline(this.owner, 9);

      await render(
        <template>
          <div class="wireframe-shell"><OutlinePanel /></div>
        </template>
      );
      await waitFor(".outline-block");
      await settled();

      assert
        .dom(".outline-block__child-count")
        .exists("the collapsed container shows a hidden-child count badge")
        .hasText("× 9", "the badge reports the child count");
      assert
        .dom(".outline-block__name")
        .exists(
          { count: 1 },
          "only the container row shows; children are hidden"
        );
    });

    test("expands a container that has few children, with no badge", async function (assert) {
      await setupOutline(this.owner, 3);

      await render(
        <template>
          <div class="wireframe-shell"><OutlinePanel /></div>
        </template>
      );
      await waitFor(".outline-block");
      await settled();

      assert
        .dom(".outline-block__child-count")
        .doesNotExist("a small container is not auto-collapsed");
      assert
        .dom(".outline-block__name")
        .exists({ count: 4 }, "the container plus its three children render");
    });

    test("numbers a carousel's child slides", async function (assert) {
      await _renderBlocks(
        "homepage-blocks",
        [
          {
            block: Carousel,
            args: {},
            children: [
              {
                block: Layout,
                args: {},
                children: [{ block: Heading, args: { text: "A" } }],
              },
              {
                block: Layout,
                args: {},
                children: [{ block: Heading, args: { text: "B" } }],
              },
            ],
          },
        ],
        this.owner
      );
      const editor = this.owner.lookup("service:wireframe-workspace");
      editor.siteSettings.wireframe_enabled = true;
      logIn(this.owner);
      editor.enter();

      await render(
        <template>
          <div class="wireframe-shell"><OutlinePanel /></div>
        </template>
      );
      await waitFor(".outline-block");
      await settled();

      // A noun-framed container's children show their position as a separate
      // chip beside the block name, so a carousel's direct children get a
      // "Slide 1" / "Slide 2" chip. The headings nested inside the slides are
      // not carousel children, so they carry no chip.
      const chips = [
        ...document.querySelectorAll(".outline-block__ordinal"),
      ].map((el) => el.textContent.trim());
      assert.deepEqual(
        chips,
        ["Slide 1", "Slide 2"],
        "each carousel child row shows its slide ordinal as a chip"
      );
      assert
        .dom(".outline-block__ordinal")
        .exists({ count: 2 }, "only the direct slides are numbered");
    });

    test("toggling a collapsed container reveals its children", async function (assert) {
      await setupOutline(this.owner, 9);

      await render(
        <template>
          <div class="wireframe-shell"><OutlinePanel /></div>
        </template>
      );
      await waitFor(".outline-block");
      await settled();

      assert
        .dom(".outline-block__name")
        .exists({ count: 1 }, "starts collapsed");

      await click(".outline-block__toggle");

      assert
        .dom(".outline-block__name")
        .exists({ count: 10 }, "expanding reveals the nine children");
      assert
        .dom(".outline-block__child-count")
        .doesNotExist("no badge once expanded");
    });

    test("cmd/ctrl-click adds a row to the selection", async function (assert) {
      await setupSiblings(this.owner, 3);
      await render(
        <template>
          <div class="wireframe-shell"><OutlinePanel /></div>
        </template>
      );
      await waitFor(".outline-block");
      await settled();

      const rows = [...document.querySelectorAll(".outline-block")];
      await click(rows[0]);
      await click(rows[1], { metaKey: true });

      assert.strictEqual(selectedRows().length, 2, "both rows are selected");
    });

    test("shift-click selects the contiguous range", async function (assert) {
      await setupSiblings(this.owner, 3);
      await render(
        <template>
          <div class="wireframe-shell"><OutlinePanel /></div>
        </template>
      );
      await waitFor(".outline-block");
      await settled();

      const rows = [...document.querySelectorAll(".outline-block")];
      await click(rows[0]);
      await click(rows[2], { shiftKey: true });

      assert.strictEqual(
        selectedRows().length,
        3,
        "the whole 0..2 range is selected"
      );
    });

    test("a plain click resets to a single selection", async function (assert) {
      await setupSiblings(this.owner, 3);
      await render(
        <template>
          <div class="wireframe-shell"><OutlinePanel /></div>
        </template>
      );
      await waitFor(".outline-block");
      await settled();

      const rows = [...document.querySelectorAll(".outline-block")];
      await click(rows[0]);
      await click(rows[1], { metaKey: true });
      assert.strictEqual(selectedRows().length, 2, "two selected after toggle");

      await click(rows[2]);
      assert.strictEqual(
        selectedRows().length,
        1,
        "a plain click collapses back to one"
      );
    });
  }
);
