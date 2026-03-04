import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import setupImageGridCarousel from "discourse/lib/image-grid-carousel";

module("Unit | setupImageGridCarousel", function (hooks) {
  setupTest(hooks);

  hooks.afterEach(function () {
    document.getElementById("qunit-fixture").innerHTML = "";
  });

  test("returns false when grid is null", function (assert) {
    assert.false(setupImageGridCarousel(null, {}));
  });

  test("returns false when grid is already initialized", function (assert) {
    const grid = document.createElement("div");
    grid.dataset.carouselInitialized = "true";
    assert.false(setupImageGridCarousel(grid, {}));
  });

  test("returns false when helper has no renderGlimmer", function (assert) {
    const grid = document.createElement("div");
    assert.false(setupImageGridCarousel(grid, {}));
  });

  test("returns false when no valid images are found", function (assert) {
    document.getElementById("qunit-fixture").innerHTML =
      `<div class="d-image-grid"></div>`;
    const grid = document.querySelector(".d-image-grid");
    const helper = { renderGlimmer: () => {} };
    assert.false(setupImageGridCarousel(grid, helper));
  });

  test("initializes carousel and returns true when images are found", function (assert) {
    document.getElementById("qunit-fixture").innerHTML = `
      <div class="d-image-grid">
        <img src="/images/avatar.png" width="10" height="10">
        <img src="/images/avatar.png" width="10" height="10">
      </div>
    `;
    const grid = document.querySelector(".d-image-grid");
    let rendered = false;
    const helper = {
      renderGlimmer: () => {
        rendered = true;
      },
    };

    assert.true(setupImageGridCarousel(grid, helper));
    assert.true(rendered);
    assert.strictEqual(grid.dataset.carouselInitialized, "true");
    assert.true(grid.classList.contains("d-image-grid--carousel"));
  });
});
