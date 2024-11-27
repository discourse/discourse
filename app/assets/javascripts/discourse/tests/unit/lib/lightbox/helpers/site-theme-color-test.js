import { module, test } from "qunit";
import sinon from "sinon";
import {
  getSiteThemeColor,
  setSiteThemeColor,
} from "discourse/lib/lightbox/helpers";

module(
  "Unit | lib | Experimental Lightbox | Helpers | getSiteThemeColor()",
  function () {
    test("gets the correct site theme color", async function (assert) {
      const querySelectorSpy = sinon.spy(document, "querySelector");
      const MetaSiteColorStub = sinon.stub(
        HTMLMetaElement.prototype,
        "content"
      );

      MetaSiteColorStub.value("#ff0000");

      const themeColor = await getSiteThemeColor();

      assert.true(querySelectorSpy.calledWith('meta[name="theme-color"]'), "Queries the correct element");

      assert.strictEqual(
        themeColor,
        "#ff0000",
        "returns the correct theme color"
      );

      querySelectorSpy.restore();
      MetaSiteColorStub.restore();
    });

    test("sets the site theme color correctly", async function (assert) {
      const querySelectorSpy = sinon.spy(document, "querySelector");

      await setSiteThemeColor("0000ff");

      assert.true(querySelectorSpy.calledWith('meta[name="theme-color"]'), "queries the correct element");

      assert.strictEqual(
        querySelectorSpy.returnValues[0].content,
        "#0000ff",
        "sets the correct theme color"
      );

      querySelectorSpy.restore();
    });

    test("invalid color given", async function (assert) {
      await setSiteThemeColor("##0000ff");

      assert.strictEqual(
        document.querySelector('meta[name="theme-color"]').content,
        "#0000ff",
        "converts to a the correct theme color"
      );
    });
  }
);
