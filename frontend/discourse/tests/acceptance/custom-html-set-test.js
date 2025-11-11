import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { setCustomHTML } from "discourse/helpers/custom-html";
import PreloadStore from "discourse/lib/preload-store";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("CustomHTML set", function () {
  test("has no custom HTML in the top", async function (assert) {
    await visit("/static/faq");
    assert.dom("span.custom-html-test").doesNotExist("has no markup");
  });

  test("renders set HTML", async function (assert) {
    setCustomHTML("top", '<span class="custom-html-test">HTML</span>');

    await visit("/static/faq");
    assert
      .dom("span.custom-html-test")
      .hasText("HTML", "it inserted the markup");
  });

  test("renders preloaded HTML", async function (assert) {
    PreloadStore.store("customHTML", {
      top: "<span class='cookie'>monster</span>",
    });

    await visit("/static/faq");
    assert.dom("span.cookie").hasText("monster", "it inserted the markup");
  });
});
