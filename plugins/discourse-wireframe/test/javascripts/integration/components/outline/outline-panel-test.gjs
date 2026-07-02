import { getOwner } from "@ember/owner";
import {
  click,
  fillIn,
  render,
  settled,
  triggerKeyEvent,
  waitFor,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import { _renderBlocks } from "discourse/blocks/block-outlet";
import Carousel from "discourse/blocks/builtin/carousel";
import Heading from "discourse/blocks/builtin/heading";
import Layout from "discourse/blocks/builtin/layout";
import Section from "discourse/blocks/builtin/section";
import DMenus from "discourse/float-kit/components/d-menus";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { logIn } from "discourse/tests/helpers/qunit-helpers";
import OutlinePanel from "discourse/plugins/discourse-wireframe/discourse/components/editor/outline/outline-panel";
import { setupBlockLayoutDraftsStub } from "../../../helpers/stub-block-layout-drafts";

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

    test("the filter input narrows the visible rows", async function (assert) {
      await setupSiblings(this.owner, 3);
      await render(
        <template>
          <div class="wireframe-shell"><OutlinePanel /></div>
        </template>
      );
      await waitFor(".outline-block");
      await settled();

      assert.dom(".outline-block").exists({ count: 3 }, "all rows show");

      await fillIn(".filter-input", "no-such-block");
      assert
        .dom(".outline-block")
        .doesNotExist("a non-matching query hides every row");

      await fillIn(".filter-input", "heading");
      assert
        .dom(".outline-block")
        .exists({ count: 3 }, "a matching query restores the rows");
    });

    test("exposes tree semantics for assistive technology", async function (assert) {
      await setupOutline(this.owner, 3);
      await render(
        <template>
          <div class="wireframe-shell"><OutlinePanel /></div>
        </template>
      );
      await waitFor(".outline-block");
      await settled();

      assert.dom(".wireframe-outline__tree").hasAttribute("role", "tree");
      assert
        .dom(".outline-outlet__header")
        .hasAttribute("role", "treeitem")
        .hasAttribute("aria-level", "1");

      // The section container row is a treeitem one level deeper that reports
      // its expanded state and (initially) unselected state.
      const container = document.querySelector(".outline-block");
      assert
        .dom(container)
        .hasAttribute("role", "treeitem")
        .hasAttribute("aria-level", "2")
        .hasAttribute("aria-expanded", "true")
        .hasAttribute("aria-selected", "false");

      await click(container);
      assert
        .dom(".outline-block")
        .hasAttribute(
          "aria-selected",
          "true",
          "selection is reflected in ARIA"
        );
    });

    test("arrow keys rove focus across the header and row boundary", async function (assert) {
      await setupSiblings(this.owner, 3);
      await render(
        <template>
          <div class="wireframe-shell"><OutlinePanel /></div>
        </template>
      );
      await waitFor(".outline-block");
      await settled();

      const header = document.querySelector(".outline-outlet__header");
      const rows = [...document.querySelectorAll(".outline-block")];

      header.focus();
      await triggerKeyEvent(header, "keydown", "ArrowDown");
      assert.strictEqual(
        document.activeElement,
        rows[0],
        "ArrowDown from the outlet header lands on the first row"
      );

      await triggerKeyEvent(rows[0], "keydown", "ArrowDown");
      assert.strictEqual(
        document.activeElement,
        rows[1],
        "ArrowDown moves to the next row"
      );

      await triggerKeyEvent(rows[1], "keydown", "ArrowUp");
      assert.strictEqual(
        document.activeElement,
        rows[0],
        "ArrowUp moves back up the tree"
      );
    });

    test("Home and End jump to the first and last tree items", async function (assert) {
      await setupSiblings(this.owner, 3);
      await render(
        <template>
          <div class="wireframe-shell"><OutlinePanel /></div>
        </template>
      );
      await waitFor(".outline-block");
      await settled();

      const header = document.querySelector(".outline-outlet__header");
      const rows = [...document.querySelectorAll(".outline-block")];

      rows[0].focus();
      await triggerKeyEvent(rows[0], "keydown", "End");
      assert.strictEqual(
        document.activeElement,
        rows[rows.length - 1],
        "End focuses the last row"
      );

      await triggerKeyEvent(document.activeElement, "keydown", "Home");
      assert.strictEqual(
        document.activeElement,
        header,
        "Home focuses the first tree item (the outlet header)"
      );
    });

    test("Enter on a focused row selects it", async function (assert) {
      await setupSiblings(this.owner, 3);
      await render(
        <template>
          <div class="wireframe-shell"><OutlinePanel /></div>
        </template>
      );
      await waitFor(".outline-block");
      await settled();

      const rows = [...document.querySelectorAll(".outline-block")];
      rows[1].focus();
      await triggerKeyEvent(rows[1], "keydown", "Enter");

      assert.strictEqual(
        selectedRows().length,
        1,
        "exactly one row is selected"
      );
      assert
        .dom(rows[1])
        .hasClass("--selected", "the focused row becomes the selection");
    });

    test("Enter on the outlet header selects the outlet root", async function (assert) {
      await setupSiblings(this.owner, 3);
      await render(
        <template>
          <div class="wireframe-shell"><OutlinePanel /></div>
        </template>
      );
      await waitFor(".outline-block");
      await settled();

      const header = document.querySelector(".outline-outlet__header");
      header.focus();
      await triggerKeyEvent(header, "keydown", "Enter");

      assert
        .dom(".outline-outlet__header")
        .hasClass("--selected", "the outlet header reads as selected");
    });

    test("Right expands and Left collapses the focused container", async function (assert) {
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
        .exists({ count: 1 }, "the large container starts collapsed");

      const container = document.querySelector(".outline-block");
      const containerKey = container.dataset.blockKey;
      container.focus();
      await triggerKeyEvent(container, "keydown", "ArrowRight");

      assert
        .dom(".outline-block__name")
        .exists({ count: 10 }, "ArrowRight expands the container");
      // The keyed `{{#each}}` reuses the row's DOM node across the re-render, so
      // keyboard focus stays on the container instead of falling to the body —
      // the tree stays navigable after a toggle.
      assert.strictEqual(
        document.activeElement?.dataset.blockKey,
        containerKey,
        "focus stays on the container after expanding"
      );

      await triggerKeyEvent(document.activeElement, "keydown", "ArrowLeft");

      assert
        .dom(".outline-block__name")
        .exists({ count: 1 }, "ArrowLeft collapses it again");
      assert.strictEqual(
        document.activeElement?.dataset.blockKey,
        containerKey,
        "focus stays on the container after collapsing"
      );
    });

    test("the row kebab menu duplicates a block", async function (assert) {
      await setupSiblings(this.owner, 2);
      await render(
        <template>
          <div class="wireframe-shell"><OutlinePanel /></div>
          <DMenus />
        </template>
      );
      await waitFor(".outline-block");
      await settled();

      const firstRow = document.querySelector(".outline-block");
      await click(firstRow.querySelector(".outline-block__actions"));
      await waitFor(".fk-d-menu");
      assert
        .dom(firstRow)
        .hasClass("--selected", "opening the kebab selects the row it acts on");
      // The menu owns focus for accessibility (its first item is autofocused),
      // rather than the focus staying on the row.
      assert.true(
        Boolean(document.activeElement.closest(".fk-d-menu")),
        "focus moves into the menu when it opens"
      );
      await click(".fk-d-menu .btn:first-child");

      assert
        .dom(".outline-block")
        .exists({ count: 3 }, "duplicating adds a sibling row");
    });

    test("closing the menu returns the cursor to the row so arrow-nav resumes there", async function (assert) {
      await setupSiblings(this.owner, 3);
      await render(
        <template>
          <div class="wireframe-shell"><OutlinePanel /></div>
          <DMenus />
        </template>
      );
      await waitFor(".outline-block");
      await settled();

      const rows = [...document.querySelectorAll(".outline-block")];
      await click(rows[0].querySelector(".outline-block__actions"));
      await waitFor(".fk-d-menu");

      // Escape closes the menu; FloatKit returns focus to the trigger (the kebab
      // inside row 0), and dRovingFocus resolves that descendant back to the row.
      await triggerKeyEvent(document.activeElement, "keydown", "Escape");

      assert.dom(".fk-d-menu").doesNotExist("Escape closes the menu");

      await triggerKeyEvent(document.activeElement, "keydown", "ArrowDown");
      assert.strictEqual(
        document.activeElement,
        rows[1],
        "arrow navigation resumes from the row the menu acted on"
      );
    });

    test("the row kebab menu deletes a block", async function (assert) {
      await setupSiblings(this.owner, 3);
      await render(
        <template>
          <div class="wireframe-shell"><OutlinePanel /></div>
          <DMenus />
        </template>
      );
      await waitFor(".outline-block");
      await settled();

      const firstRow = document.querySelector(".outline-block");
      await click(firstRow.querySelector(".outline-block__actions"));
      await waitFor(".fk-d-menu");
      await click(".fk-d-menu .wireframe-outline__row-action--danger");

      assert
        .dom(".outline-block")
        .exists({ count: 2 }, "deleting removes the row");
    });
  }
);
