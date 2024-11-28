import { module, test } from "qunit";
import { preloadItemImages } from "discourse/lib/lightbox/helpers";
import {
  generateLightboxObject,
  LIGHTBOX_IMAGE_FIXTURES,
} from "discourse/tests/helpers/lightbox-helpers";
import { cloneJSON } from "discourse-common/lib/object";

module(
  "Unit | lib | Experimental Lightbox | Helpers | preloadItemImages()",
  function () {
    const baseLightboxItem = generateLightboxObject().items[0];

    test("returns the correct object", async function (assert) {
      const lightboxItem = cloneJSON(baseLightboxItem);

      const result = await preloadItemImages(lightboxItem);

      assert.true(result.isLoaded, "isLoaded should be true");

      assert.false(result.hasLoadingError, "hasLoadingError should be false");

      assert.strictEqual(
        result.width,
        LIGHTBOX_IMAGE_FIXTURES.first.width,
        "width should be equal to fullsizeImage width"
      );

      assert.strictEqual(
        result.height,
        LIGHTBOX_IMAGE_FIXTURES.first.height,
        "height should be equal to fullsizeImage height"
      );

      assert.strictEqual(
        result.aspectRatio,
        LIGHTBOX_IMAGE_FIXTURES.first.aspectRatio,
        "aspectRatio should be equal to image width/height"
      );

      assert.true(
        result.canZoom,
        "canZoom should be true if fullsizeImage width or height is greater than window inner width or height"
      );
    });

    test("handles errors", async function (assert) {
      const lightboxItem = cloneJSON(baseLightboxItem);

      lightboxItem.fullsizeURL =
        LIGHTBOX_IMAGE_FIXTURES.invalidImage.fullsizeURL;

      const result = await preloadItemImages(lightboxItem);

      assert.true(
        result.hasLoadingError,
        "sets hasLoadingError to true if there is an error"
      );
    });

    test("handles images smaller than the viewport", async function (assert) {
      const lightboxItem = cloneJSON(baseLightboxItem);

      lightboxItem.fullsizeURL =
        LIGHTBOX_IMAGE_FIXTURES.smallerThanViewPort.fullsizeURL;

      const result = await preloadItemImages(lightboxItem);

      assert.false(
        result.canZoom,
        "canZoom should be false if fullsizeImage width or height is smaller than window inner width or height"
      );
    });
  }
);
