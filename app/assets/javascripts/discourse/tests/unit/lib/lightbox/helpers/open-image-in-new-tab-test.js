import { module, test } from "qunit";
import sinon from "sinon";
import { openImageInNewTab } from "discourse/lib/lightbox/helpers";

module(
  "Unit | lib | Experimental Lightbox | Helpers | openImageinNewTab()",
  function () {
    test("opens the fullsize URL of the lightbox item in a new tab", async function (assert) {
      const lightboxItem = {
        fullsizeURL: "image.jpg",
      };

      const openStub = sinon.stub(window, "open");

      await openImageInNewTab(lightboxItem);

      assert.true(
        openStub.calledWith("image.jpg", "_blank"),
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

      assert.true(consoleErrorStub.called, "logs an error to the console");

      openStub.restore();
      consoleErrorStub.restore();
    });
  }
);
