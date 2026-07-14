import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { sortLightboxItems } from "discourse/lib/lightbox";

module("Unit | lightbox | sortLightboxItems", function (hooks) {
  setupTest(hooks);

  hooks.afterEach(function () {
    document.getElementById("qunit-fixture").innerHTML = "";
  });

  test("preserves order of items outside a grid", function (assert) {
    document.getElementById("qunit-fixture").innerHTML = `
      <a class="lightbox" href="/a.png"></a>
      <a class="lightbox" href="/b.png"></a>
      <div class="d-image-grid" data-columns="2">
        <div class="d-image-grid-column">
          <a class="lightbox" href="/1.png" data-lightbox-position="0"></a>
          <a class="lightbox" href="/3.png" data-lightbox-position="2"></a>
        </div>
        <div class="d-image-grid-column">
          <a class="lightbox" href="/2.png" data-lightbox-position="1"></a>
          <a class="lightbox" href="/4.png" data-lightbox-position="3"></a>
        </div>
      </div>
      <a class="lightbox" href="/c.png"></a>
    `;

    const items = sortLightboxItems([
      ...document.querySelectorAll(".lightbox"),
    ]);

    assert.deepEqual(
      items.map((el) => el.getAttribute("href")),
      ["/a.png", "/b.png", "/1.png", "/2.png", "/3.png", "/4.png", "/c.png"]
    );
  });

  test("sorts each grid independently", function (assert) {
    document.getElementById("qunit-fixture").innerHTML = `
      <div class="d-image-grid" data-columns="2">
        <div class="d-image-grid-column">
          <a class="lightbox" href="/a1.png" data-lightbox-position="0"></a>
          <a class="lightbox" href="/a3.png" data-lightbox-position="2"></a>
        </div>
        <div class="d-image-grid-column">
          <a class="lightbox" href="/a2.png" data-lightbox-position="1"></a>
          <a class="lightbox" href="/a4.png" data-lightbox-position="3"></a>
        </div>
      </div>
      <div class="d-image-grid" data-columns="2">
        <div class="d-image-grid-column">
          <a class="lightbox" href="/b1.png" data-lightbox-position="0"></a>
          <a class="lightbox" href="/b3.png" data-lightbox-position="2"></a>
        </div>
        <div class="d-image-grid-column">
          <a class="lightbox" href="/b2.png" data-lightbox-position="1"></a>
          <a class="lightbox" href="/b4.png" data-lightbox-position="3"></a>
        </div>
      </div>
    `;

    const items = sortLightboxItems([
      ...document.querySelectorAll(".lightbox"),
    ]);

    assert.deepEqual(
      items.map((el) => el.getAttribute("href")),
      [
        "/a1.png",
        "/a2.png",
        "/a3.png",
        "/a4.png",
        "/b1.png",
        "/b2.png",
        "/b3.png",
        "/b4.png",
      ]
    );
  });

  test("preserves grid DOM order when positions are missing", function (assert) {
    document.getElementById("qunit-fixture").innerHTML = `
      <div class="d-image-grid" data-columns="2">
        <div class="d-image-grid-column">
          <a class="lightbox" href="/1.png" data-lightbox-position="0"></a>
          <a class="lightbox" href="/3.png" data-lightbox-position="2"></a>
        </div>
        <div class="d-image-grid-column">
          <a class="lightbox" href="/2.png"></a>
          <a class="lightbox" href="/4.png" data-lightbox-position="3"></a>
        </div>
      </div>
    `;

    const items = sortLightboxItems([
      ...document.querySelectorAll(".lightbox"),
    ]);

    assert.deepEqual(
      items.map((el) => el.getAttribute("href")),
      ["/1.png", "/3.png", "/2.png", "/4.png"]
    );
  });

  test("preserves grid DOM order when positions are invalid", function (assert) {
    document.getElementById("qunit-fixture").innerHTML = `
      <div class="d-image-grid" data-columns="2">
        <div class="d-image-grid-column">
          <a class="lightbox" href="/1.png" data-lightbox-position="0"></a>
          <a class="lightbox" href="/3.png" data-lightbox-position="2"></a>
        </div>
        <div class="d-image-grid-column">
          <a class="lightbox" href="/2.png" data-lightbox-position="1x"></a>
          <a class="lightbox" href="/4.png" data-lightbox-position="3"></a>
        </div>
      </div>
    `;

    const items = sortLightboxItems([
      ...document.querySelectorAll(".lightbox"),
    ]);

    assert.deepEqual(
      items.map((el) => el.getAttribute("href")),
      ["/1.png", "/3.png", "/2.png", "/4.png"]
    );
  });
});
