import {
  acceptance,
  exists,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import PreloadStore from "discourse/lib/preload-store";
import { setCustomHTML } from "discourse/helpers/custom-html";
import { test } from "qunit";
import { visit } from "@ember/test-helpers";

acceptance("CustomHTML set", function () {
  test("has no custom HTML in the top", async function (assert) {
    await visit("/static/faq");
    assert.ok(!exists("span.custom-html-test"), "it has no markup");
  });

  test("renders set HTML", async function (assert) {
    setCustomHTML("top", '<span class="custom-html-test">HTML</span>');

    await visit("/static/faq");
    assert.strictEqual(
      queryAll("span.custom-html-test").text(),
      "HTML",
      "it inserted the markup"
    );
  });

  test("renders preloaded HTML", async function (assert) {
    PreloadStore.store("customHTML", {
      top: "<span class='cookie'>monster</span>",
    });

    await visit("/static/faq");
    assert.strictEqual(
      queryAll("span.cookie").text(),
      "monster",
      "it inserted the markup"
    );
  });
});
