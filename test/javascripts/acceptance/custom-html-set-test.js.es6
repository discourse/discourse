import { acceptance } from "helpers/qunit-helpers";
import { setCustomHTML } from "discourse/helpers/custom-html";
import PreloadStore from "preload-store";

acceptance("CustomHTML set");

QUnit.test("has no custom HTML in the top", assert => {
  visit("/static/faq");
  andThen(() => {
    assert.ok(!exists("span.custom-html-test"), "it has no markup");
  });
});

QUnit.test("renders set HTML", assert => {
  setCustomHTML("top", '<span class="custom-html-test">HTML</span>');

  visit("/static/faq");
  andThen(() => {
    assert.equal(
      find("span.custom-html-test").text(),
      "HTML",
      "it inserted the markup"
    );
  });
});

QUnit.test("renders preloaded HTML", assert => {
  PreloadStore.store("customHTML", {
    top: "<span class='cookie'>monster</span>"
  });

  visit("/static/faq");
  andThen(() => {
    assert.equal(
      find("span.cookie").text(),
      "monster",
      "it inserted the markup"
    );
  });
});
