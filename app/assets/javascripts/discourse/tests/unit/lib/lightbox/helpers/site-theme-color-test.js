import {
  getSiteThemeColor,
  setSiteThemeColor,
} from "discourse/lib/lightbox/helpers";
import { module, test } from "qunit";

import sinon from "sinon";

module(
  "Unit | lib | Experimental Lightbox | Helpers | getSiteThemeColor()",
  function () {
    test("gets the correct site theme color", async function (assert) {
      const querySelectorStub = sinon
        .stub(document, "querySelector")
        .returns({ content: "#ff0000" });

      const themeColor = await getSiteThemeColor();

      assert.strictEqual(
        querySelectorStub.calledWith('meta[name="theme-color"]'),
        true,
        "Queries the correct element"
      );

      assert.strictEqual(
        themeColor,
        "#ff0000",
        "returns the correct theme color"
      );

      querySelectorStub.restore();
    });

    test("sets the site theme color correctly", async function (assert) {
      const querySelectorStub = sinon
        .stub(document, "querySelector")
        .returns({ content: "#ff0000" });

      await setSiteThemeColor("0000ff");

      assert.strictEqual(
        querySelectorStub.calledWith('meta[name="theme-color"]'),
        true,
        "Queries the correct element"
      );

      assert.strictEqual(
        querySelectorStub.returnValues[0].content,
        "#0000ff",
        "sets the correct theme color"
      );

      querySelectorStub.restore();
    });
  }
);
