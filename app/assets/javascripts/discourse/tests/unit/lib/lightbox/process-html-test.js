import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import domFromString from "discourse/lib/dom-from-string";
import { SELECTORS } from "discourse/lib/lightbox/constants";
import { processHTML } from "discourse/lib/lightbox/process-html";
import {
  generateImageUploaderMarkup,
  generateLightboxMarkup,
  LIGHTBOX_IMAGE_FIXTURES,
} from "discourse/tests/helpers/lightbox-helpers";

module("Unit | lib | Experimental lightbox | processHTML()", function (hooks) {
  setupTest(hooks);

  const wrap = domFromString(generateLightboxMarkup())[0];
  const imageUploaderWrap = domFromString(generateImageUploaderMarkup())[0];
  const selector = SELECTORS.DEFAULT_ITEM_SELECTOR;

  test("returns the correct object from the processed element", async function (assert) {
    const container = wrap.cloneNode(true);

    const { items, startingIndex } = await processHTML({
      container,
      selector,
    });

    assert.strictEqual(items.length, 1);

    const item = items[0];

    assert.strictEqual(
      item.fullsizeURL,
      LIGHTBOX_IMAGE_FIXTURES.first.fullsizeURL
    );

    assert.strictEqual(item.smallURL, LIGHTBOX_IMAGE_FIXTURES.first.smallURL);

    assert.strictEqual(
      item.downloadURL,
      LIGHTBOX_IMAGE_FIXTURES.first.downloadURL
    );

    assert.strictEqual(items[0].title, LIGHTBOX_IMAGE_FIXTURES.first.title);

    assert.strictEqual(
      item.fileDetails,
      LIGHTBOX_IMAGE_FIXTURES.first.fileDetails
    );

    assert.strictEqual(
      item.dominantColor,
      LIGHTBOX_IMAGE_FIXTURES.first.dominantColor
    );

    assert.strictEqual(
      item.aspectRatio,
      LIGHTBOX_IMAGE_FIXTURES.first.aspectRatio
    );

    assert.strictEqual(item.index, LIGHTBOX_IMAGE_FIXTURES.first.index);

    assert.strictEqual(
      item.cssVars.toString(),
      LIGHTBOX_IMAGE_FIXTURES.first.cssVars.toString()
    );

    assert.strictEqual(startingIndex, 0);
  });

  test("returns the correct number of items", async function (assert) {
    const htmlString = generateLightboxMarkup().repeat(3);
    const container = domFromString(htmlString);

    const outer = document.createElement("div");
    outer.append(...container);

    const { items } = await processHTML({
      container: outer,
      selector,
    });

    assert.strictEqual(items.length, 3);
  });

  test("falls back to src when no href is defined for fullsizeURL", async function (assert) {
    const container = wrap.cloneNode(true);

    container.querySelector("a").removeAttribute("href");

    const { items } = await processHTML({
      container,
      selector,
    });

    assert.strictEqual(
      items[0].fullsizeURL,
      LIGHTBOX_IMAGE_FIXTURES.first.smallURL
    );
  });

  test("handles title fallbacks", async function (assert) {
    const container = wrap.cloneNode(true);

    container.querySelector("a").removeAttribute("title");

    let { items } = await processHTML({
      container,
      selector,
    });

    assert.strictEqual(items[0].title, LIGHTBOX_IMAGE_FIXTURES.first.title);

    container.querySelector("img").removeAttribute("title");

    ({ items } = await processHTML({
      container,
      selector,
    }));

    assert.strictEqual(items[0].title, LIGHTBOX_IMAGE_FIXTURES.first.alt);

    container.querySelector("img").removeAttribute("alt");

    ({ items } = await processHTML({
      container,
      selector,
    }));

    assert.strictEqual(items[0].title, "");
  });

  test("handles missing aspect ratio", async function (assert) {
    const container = wrap.cloneNode(true);

    container.querySelector("img").style.removeProperty("aspect-ratio");

    const { items } = await processHTML({
      container,
      selector,
    });

    assert.strictEqual(items[0].aspectRatio, null);

    assert.strictEqual(
      items[0].cssVars.toString(),
      `--dominant-color: #${LIGHTBOX_IMAGE_FIXTURES.first.dominantColor};--small-url: url(${LIGHTBOX_IMAGE_FIXTURES.first.smallURL});`
    );
  });

  test("handles missing file details", async function (assert) {
    const container = wrap.cloneNode(true);

    container.querySelector(SELECTORS.FILE_DETAILS_CONTAINER).remove();

    const { items } = await processHTML({
      container,
      selector,
    });

    assert.strictEqual(items[0].fileDetails, null);
  });

  test("handles missing dominant color", async function (assert) {
    const container = wrap.cloneNode(true);

    container.querySelector("img").removeAttribute("data-dominant-color");

    const { items } = await processHTML({
      container,
      selector,
    });

    assert.strictEqual(items[0].dominantColor, null);

    assert.strictEqual(
      items[0].cssVars.toString(),
      `--aspect-ratio: ${LIGHTBOX_IMAGE_FIXTURES.first.aspectRatio};--small-url: url(${LIGHTBOX_IMAGE_FIXTURES.first.smallURL});`
    );
  });

  test("falls back to href when data-download is not defined", async function (assert) {
    const container = wrap.cloneNode(true);

    container.querySelector("a").removeAttribute("data-download-href");

    const { items } = await processHTML({
      container,
      selector,
    });

    assert.strictEqual(
      items[0].downloadURL,
      LIGHTBOX_IMAGE_FIXTURES.first.fullsizeURL
    );
  });

  test("handles missing selector", async function (assert) {
    const container = wrap.cloneNode(true);

    const { items } = await processHTML({
      container,
    });

    assert.strictEqual(items.length, 1);
  });

  test("handles custom selector", async function (assert) {
    const container = wrap.cloneNode(true);
    container.querySelector("a").classList.add("custom-selector");

    const { items } = await processHTML({
      container,
      selector: ".custom-selector",
    });

    assert.strictEqual(items.length, 1);
  });

  test("returns the correct object for image uploader components", async function (assert) {
    const container = imageUploaderWrap.cloneNode(true);

    const { items } = await processHTML({
      container,
      selector,
    });

    const item = items[0];

    assert.strictEqual(items.length, 1);

    assert.strictEqual(item.title, "");

    assert.strictEqual(item.aspectRatio, null);

    assert.strictEqual(item.dominantColor, null);

    assert.strictEqual(item.fileDetails, "x");

    assert.strictEqual(
      item.downloadURL,
      LIGHTBOX_IMAGE_FIXTURES.first.fullsizeURL
    );

    assert.strictEqual(
      item.smallURL,
      LIGHTBOX_IMAGE_FIXTURES.first.fullsizeURL
    );

    assert.strictEqual(
      item.fullsizeURL,
      LIGHTBOX_IMAGE_FIXTURES.first.fullsizeURL
    );

    assert.strictEqual(
      item.cssVars.toString(),
      `--small-url: url(${LIGHTBOX_IMAGE_FIXTURES.first.fullsizeURL});`
    );
  });

  test("throws missing container error when no container / nodelist is passed", async function (assert) {
    assert.rejects(processHTML({ selector }));
  });
});
