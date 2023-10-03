import { module, test } from "qunit";

import { openImageInNewTab } from "discourse/lib/lightbox/helpers";
import sinon from "sinon";

module(
  "Unit | lib | Experimental Lightbox | Helpers | openImageinNewTab()",
  function () {
    test("opens the fullsize URL of the lightbox item in a new tab", async function (assert) {
      const lightboxItem = {
        fullsizeURL: "image.jpg",
      };

      const openStub = sinon.stub(window, "open");

      await openImageInNewTab(lightboxItem);

      assert.strictEqual(
        openStub.calledWith("image.jpg", "_blank"),
        true,
        "calls window.open with the correct arguments"
      );

      openStub.restore();
    });

    test("handles errors when trying to open the new tab", async function (assert) {
      const lightboxItem = {
        fullsizeURL: "image.jpg",
      };

      const openStub = sinon.stub(window, "open").throws();
      const consoleErrorStub = sinon.stub(console, "error");

      await openImageInNewTab(lightboxItem);

      assert.strictEqual(
        consoleErrorStub.called,
        true,
        "logs an error to the console"
      );

      openStub.restore();
      consoleErrorStub.restore();
    });
  }
);
