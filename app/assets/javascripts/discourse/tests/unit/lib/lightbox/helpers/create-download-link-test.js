import { module, test } from "qunit";
import sinon from "sinon";
import { createDownloadLink } from "discourse/lib/lightbox/helpers";

module(
  "Unit | lib | Experimental Lightbox | Helpers | createDownloadLink()",
  function () {
    test("creates a download link with the correct href and download attributes", async function (assert) {
      const lightboxItem = {
        downloadURL: "http://example.com/download.jpg",
        title: "image.jpg",
      };
      const createElementSpy = sinon.spy(document, "createElement");
      const clickStub = sinon.stub(HTMLAnchorElement.prototype, "click");

      createDownloadLink(lightboxItem);

      assert.true(
        createElementSpy.calledWith("a"),
        "creates an anchor element"
      );

      assert.strictEqual(
        createElementSpy.returnValues[0].href,
        "http://example.com/download.jpg",
        "sets the correct href attribute"
      );

      assert.strictEqual(
        createElementSpy.returnValues[0].download,
        "image.jpg",
        "sets the correct download attribute"
      );

      assert.true(clickStub.called, "clicks the link element");

      createElementSpy.restore();
      clickStub.restore();
    });
  }
);
