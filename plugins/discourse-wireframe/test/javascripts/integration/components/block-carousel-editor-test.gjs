import { getOwner } from "@ember/owner";
import { click, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import BlockOutlet, {
  _renderBlocks,
  _resetOutletLayoutsForTesting,
} from "discourse/blocks/block-outlet";
import Carousel from "discourse/blocks/builtin/carousel";
import Heading from "discourse/blocks/builtin/heading";
import Layout from "discourse/blocks/builtin/layout";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { logIn } from "discourse/tests/helpers/qunit-helpers";
import { entryKey } from "discourse/plugins/discourse-wireframe/discourse/lib/mutate-layout";
import { setupBlockLayoutDraftsStub } from "../../helpers/stub-block-layout-drafts";

const OUTLET = "homepage-blocks";

// After `enter()` the outlet is wrapped in a single root `layout`; its first
// child is the carousel under test.
function carouselEntry(editor) {
  return editor.wireframeLayoutQuery.readResolvedLayout(OUTLET)?.[0]
    ?.children?.[0];
}

function slideLayout(text) {
  return {
    block: Layout,
    args: {},
    children: [{ block: Heading, args: { text } }],
  };
}

module(
  "Integration | discourse-wireframe | carousel in the editor",
  function (hooks) {
    setupRenderingTest(hooks);
    setupBlockLayoutDraftsStub(hooks);

    hooks.beforeEach(async function () {
      await _renderBlocks(
        OUTLET,
        [
          {
            block: Carousel,
            args: {},
            children: [slideLayout("One"), slideLayout("Two")],
          },
        ],
        getOwner(this)
      );
      this.editor = getOwner(this).lookup("service:wireframe");
      this.editor.siteSettings.wireframe_enabled = true;
      logIn(getOwner(this));
      this.editor.enter();
    });

    hooks.afterEach(function () {
      this.editor.exit();
      _resetOutletLayoutsForTesting();
    });

    test("a block inside a slide is selectable", async function (assert) {
      await render(<template><BlockOutlet @name={{OUTLET}} /></template>);

      const carousel = carouselEntry(this.editor);
      const carouselKey = entryKey(carousel);
      const firstSlide = carousel.children[0];
      const headingKey = entryKey(firstSlide.children[0]);

      await click(".d-block-carousel__slide .d-block-heading", { detail: 1 });

      assert.strictEqual(
        this.editor.wireframeSelection.selectedBlockKey,
        headingKey,
        "clicking inside the first slide selects the heading inside it"
      );
      assert.notStrictEqual(
        this.editor.wireframeSelection.selectedBlockKey,
        carouselKey,
        "the click does not get captured by the carousel itself"
      );
    });

    test("the next control pages the carousel in the editor", async function (assert) {
      await render(<template><BlockOutlet @name={{OUTLET}} /></template>);

      const dots = () => [
        ...document.querySelectorAll(".d-block-carousel__dot"),
      ];
      assert.dom(dots()[0]).hasClass("is-active", "starts on the first slide");

      await click(".d-block-carousel__nav--next", { detail: 1 });

      assert
        .dom(dots()[1])
        .hasClass("is-active", "next pages to the second slide");
    });

    test("paging still works after inserting a slide between two others", async function (assert) {
      await render(<template><BlockOutlet @name={{OUTLET}} /></template>);

      const dots = () => [
        ...document.querySelectorAll(".d-block-carousel__dot"),
      ];

      // Insert a new slide between the two existing ones — the regression: the
      // index-keyed slide registry could desync on a mid-list insert, leaving
      // the nav controls unable to page to the shifted/new slides.
      const firstSlideKey = entryKey(carouselEntry(this.editor).children[0]);
      this.editor.wireframeBlockMutations.insertBlock({
        blockName: "heading",
        targetKey: firstSlideKey,
        position: "after",
        targetOutletName: OUTLET,
      });
      await settled();

      assert
        .dom(".d-block-carousel__slide")
        .exists({ count: 3 }, "the carousel now has three slides");

      // The controls must still drive the track to every slide.
      await click(".d-block-carousel__nav--next", { detail: 1 });
      assert
        .dom(dots()[1])
        .hasClass("is-active", "next pages to the inserted middle slide");

      await click(dots()[2], { detail: 1 });
      assert
        .dom(dots()[2])
        .hasClass("is-active", "the last dot pages to the last slide");
    });
  }
);
