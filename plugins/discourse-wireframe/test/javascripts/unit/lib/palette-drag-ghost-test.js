import { module, test } from "qunit";
import { buildPaletteDragGhost } from "discourse/plugins/discourse-wireframe/discourse/lib/palette-drag-ghost";

function element(html) {
  const host = document.createElement("div");
  host.innerHTML = html;
  return host.firstElementChild;
}

module("Unit | Discourse Wireframe | lib/palette-drag-ghost", function () {
  test("turns a row into a tile-shaped ghost with the sketch and the name only", function (assert) {
    const row = element(`
      <div class="wireframe-block-row" aria-label="Card" data-block-name="card">
        <svg class="wireframe-block-row__thumbnail"><rect /></svg>
        <span class="wireframe-block-row__text">
          <span class="wireframe-block-row__name">Card</span>
          <span class="wireframe-block-row__description">A card with an image.</span>
        </span>
      </div>`);

    const ghost = buildPaletteDragGhost(row);

    assert.true(ghost.classList.contains("wireframe-block-tile"));
    assert.true(ghost.classList.contains("--ghost"));
    assert.strictEqual(
      ghost.querySelectorAll(".wireframe-block-tile__thumbnail").length,
      1,
      "the sketch comes along, re-dressed as a tile thumbnail"
    );
    assert.strictEqual(
      ghost.querySelector(".wireframe-block-tile__label").textContent,
      "Card"
    );
    assert.false(
      ghost.textContent.includes("A card with an image."),
      "the description stays behind"
    );
    assert.strictEqual(
      row.querySelectorAll(".wireframe-block-row__thumbnail").length,
      1,
      "the source keeps its own sketch"
    );
  });

  test("keeps a tile as a tile, minus its screen-reader text", function (assert) {
    const tile = element(`
      <div class="wireframe-block-tile" aria-label="Heading" data-block-name="heading">
        <svg class="wireframe-block-tile__thumbnail"><rect /></svg>
        <span class="wireframe-block-tile__label">Heading</span>
        <span class="sr-only">A configurable section heading.</span>
      </div>`);

    const ghost = buildPaletteDragGhost(tile);

    assert.notStrictEqual(ghost, tile);
    assert.strictEqual(
      ghost.querySelectorAll(".wireframe-block-tile__thumbnail").length,
      1
    );
    assert.strictEqual(ghost.textContent.trim(), "Heading");
  });
});
