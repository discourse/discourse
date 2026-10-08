import {
  clearRender,
  render,
  settled,
  triggerEvent,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import DTooltips from "discourse/float-kit/components/d-tooltips";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import BlockTile from "discourse/plugins/discourse-wireframe/discourse/components/editor/palette/block-tile";
import blockPreview, {
  BLOCK_PREVIEW_IDENTIFIER,
} from "discourse/plugins/discourse-wireframe/discourse/modifiers/block-preview";

const ENTRIES = [
  {
    id: "heading",
    blockName: "heading",
    defaultArgs: {},
    variantOrder: 0,
    displayName: "Heading",
    icon: "heading",
    category: "text",
    description: "A title.",
    namespaceType: "core",
    thumbnail: null,
    paletteHidden: false,
  },
  {
    id: "paragraph",
    blockName: "paragraph",
    defaultArgs: {},
    variantOrder: 0,
    displayName: "Paragraph",
    icon: "paragraph",
    category: "text",
    description: "Body text.",
    namespaceType: "core",
    thumbnail: null,
    paletteHidden: false,
  },
];

const entryFor = (id) => ENTRIES.find((entry) => entry.id === id);

const tile = (id) => `.wireframe-block-tile[data-palette-id="${id}"]`;

const CARD = `.fk-d-tooltip__content[data-identifier="${BLOCK_PREVIEW_IDENTIFIER}"]`;

// `triggerEvent` waits for settledness, which runs every pending timer; this
// dispatches without waiting, for asserting what happens before a timer fires.
function pointerOver(selector) {
  document
    .querySelector(selector)
    .dispatchEvent(new PointerEvent("pointerover", { bubbles: true }));
}

module(
  "Integration | discourse-wireframe | Modifier | block-preview",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.tooltip = this.owner.lookup("service:tooltip");
      this.preview = () =>
        [...this.tooltip.registeredTooltips].find(
          (instance) => instance.options.identifier === BLOCK_PREVIEW_IDENTIFIER
        );
    });

    async function renderGrid() {
      await render(
        <template>
          <DTooltips />
          <div class="grid" {{blockPreview entryFor=entryFor}}>
            <div class="grid__header">Content</div>
            {{#each ENTRIES as |entry|}}
              <BlockTile @entry={{entry}} />
            {{/each}}
          </div>
        </template>
      );
    }

    test("opens one preview for the tile the pointer rests on", async function (assert) {
      await renderGrid();

      pointerOver(tile("heading"));
      assert.strictEqual(
        this.preview(),
        undefined,
        "the preview waits for the pointer to rest before opening"
      );

      await settled();
      const preview = this.preview();
      assert.true(
        preview?.expanded,
        "the preview opened once the pointer rested"
      );
      assert.strictEqual(
        preview.trigger,
        document.querySelector(tile("heading")),
        "anchored to the tile under the pointer"
      );
      assert.strictEqual(preview.options.data.entry.id, "heading");
      assert
        .dom(`${CARD} .wireframe-block-preview__name`)
        .hasText("Heading", "the card is on screen for that entry");
    });

    test("moving to another tile re-anchors the same preview instead of reopening", async function (assert) {
      await renderGrid();
      await triggerEvent(tile("heading"), "pointerover");

      const first = this.preview();

      await triggerEvent(tile("paragraph"), "pointerover");
      const second = this.preview();
      assert.strictEqual(second, first, "the open instance is reused");
      assert.true(second.expanded, "it never closed on the way");
      assert.strictEqual(
        second.trigger,
        document.querySelector(tile("paragraph")),
        "it now follows the new tile"
      );
      assert.strictEqual(
        second.options.data.entry.id,
        "paragraph",
        "and describes the new entry"
      );
    });

    test("a pointer passing through opens nothing", async function (assert) {
      await renderGrid();
      await triggerEvent(tile("heading"), "pointerover");
      await triggerEvent(".grid", "pointerleave");

      assert.strictEqual(this.preview(), undefined);
    });

    test("closes after a grace period once the pointer leaves the tiles", async function (assert) {
      await renderGrid();
      await triggerEvent(tile("heading"), "pointerover");

      assert.true(this.preview().expanded);

      pointerOver(".grid__header");
      assert.true(
        this.preview().expanded,
        "crossing a gutter or header does not close it outright"
      );
      await settled();
      assert.strictEqual(
        this.preview(),
        undefined,
        "it closes once the grace period lapses"
      );
    });

    test("starting a drag closes the preview at once", async function (assert) {
      await renderGrid();
      await triggerEvent(tile("heading"), "pointerover");

      const preview = this.preview();

      await triggerEvent(tile("heading"), "dragstart");
      assert.false(preview.expanded, "closed before the drag ghost appears");
    });

    test("tearing down the grid closes the preview", async function (assert) {
      await renderGrid();
      await triggerEvent(tile("heading"), "pointerover");

      assert.true(this.preview().expanded);

      await clearRender();
      assert.strictEqual(this.preview(), undefined);
    });
  }
);
