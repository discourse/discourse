import { module, test } from "qunit";
import Columns from "discourse/lib/columns";

module("Unit | Columns", function (hooks) {
  hooks.afterEach(function () {
    document.getElementById("qunit-fixture").innerHTML = "";
  });

  test("works", function (assert) {
    document.getElementById(
      "qunit-fixture"
    ).innerHTML = `<div class="d-image-grid">
<p><img src="/images/avatar.png" alt role="presentation"><br>
<img src="/images/avatar.png" alt role="presentation"><br>
<img src="/images/avatar.png" alt role="presentation"></p>
</div>`;

    const grid = document.querySelector(".d-image-grid");
    const cols = new Columns(grid);
    assert.strictEqual(cols.items.length, 3);

    assert.strictEqual(
      grid.dataset.columns,
      "3",
      "column count attribute is correct"
    );

    assert.strictEqual(
      document.querySelectorAll(".d-image-grid > .d-image-grid-column").length,
      3,
      "three column elements are rendered"
    );
  });

  test("disabled if items < minCount", function (assert) {
    document.getElementById(
      "qunit-fixture"
    ).innerHTML = `<div class="d-image-grid">
<p><img src="/images/avatar.png" alt role="presentation"><br>
<img src="/images/avatar.png" alt role="presentation"></p>
</div>`;

    const grid = document.querySelector(".d-image-grid");
    const cols = new Columns(grid, { minCount: 3 });

    assert.strictEqual(cols.items.length, 2);

    assert.strictEqual(
      grid.dataset.disabled,
      "true",
      "disabled attribute is added"
    );
    assert.strictEqual(
      document.querySelectorAll(".d-image-grid > .d-image-grid-column").length,
      0,
      "no column elements are rendered"
    );
  });

  test("4 items shown in 2x2 grid", function (assert) {
    document.getElementById(
      "qunit-fixture"
    ).innerHTML = `<div class="d-image-grid">
<img src="/images/avatar.png" width="20" height="20" role="presentation">
<img src="/images/avatar.png" width="20" height="20" role="presentation">
<img src="/images/avatar.png" width="20" height="20" role="presentation">
<img src="/images/avatar.png" width="20" height="20" role="presentation">
</div>`;

    const grid = document.querySelector(".d-image-grid");
    const cols = new Columns(grid);

    assert.strictEqual(cols.items.length, 4);
    assert.strictEqual(
      grid.dataset.columns,
      "2",
      "column count attribute is correct"
    );
    assert.strictEqual(
      document.querySelectorAll(".d-image-grid > .d-image-grid-column").length,
      2,
      "two columns are rendered"
    );

    assert.strictEqual(
      document.querySelectorAll(
        ".d-image-grid > .d-image-grid-column:first-child .image-wrapper"
      ).length,
      2,
      "two images in column 1"
    );

    assert.strictEqual(
      document.querySelectorAll(
        ".d-image-grid > .d-image-grid-column:nth-child(2) .image-wrapper"
      ).length,
      2,
      "two images in column 2"
    );
  });

  test("non-image elements", function (assert) {
    document.getElementById(
      "qunit-fixture"
    ).innerHTML = `<div class="d-image-grid">
<img src="/images/avatar.png" width="20" height="20" role="presentation">
<img src="/images/avatar.png" width="20" height="20" role="presentation">
<img src="/images/avatar.png" width="20" height="20" role="presentation">
<div style="width: 20px; height: 20px; background-color: red;">hey there</div>
<div style="width: 20px; height: 20px; background-color: red;">hey there</div>
</div>`;

    const grid = document.querySelector(".d-image-grid");
    const cols = new Columns(grid);

    assert.strictEqual(cols.items.length, 5);
    assert.strictEqual(cols.container, grid);

    assert.strictEqual(
      grid.dataset.columns,
      "3",
      "column count attribute is correct"
    );
    assert.strictEqual(
      document.querySelectorAll(".d-image-grid > .d-image-grid-column").length,
      3,
      "three columns are rendered"
    );

    assert.strictEqual(
      document.querySelectorAll(
        ".d-image-grid > .d-image-grid-column:first-child > *"
      ).length,
      2,
      "two elements in column 1"
    );

    assert.strictEqual(
      document.querySelectorAll(
        ".d-image-grid > .d-image-grid-column:nth-child(2) > *"
      ).length,
      2,
      "two elements in column 2"
    );

    assert.strictEqual(
      document.querySelectorAll(
        ".d-image-grid > .d-image-grid-column:nth-child(3) > *"
      ).length,
      1,
      "one element in column 3"
    );
  });
});
