import { setLocalCache } from "pretty-text/oneboxer-cache";
import { module, test } from "qunit";
import { buildEngine } from "discourse/static/markdown-it";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module(
  "Integration | Component | prosemirror-editor - onebox extension",
  function (hooks) {
    setupRenderingTest(hooks);

    // Oneboxes are parsed as links with "linkify" markup
    test("onebox can be omitted as a markdown-it feature", async function (assert) {
      const testUrl = "https://www.example.com";
      const cachedOneboxHtml = '<aside class="onebox">onebox</aside>';

      const cachedElement = document.createElement("div");
      cachedElement.innerHTML = cachedOneboxHtml;
      setLocalCache(testUrl, cachedElement);

      const markdownIt = buildEngine(null, ["onebox"]);
      const cookedHtml = markdownIt.cook(testUrl);

      assert.true(
        cookedHtml.includes(`<a href="${testUrl}">${testUrl}</a>`),
        "URL should render as plain link when onebox is omitted"
      );

      setLocalCache(testUrl, null);
    });
  }
);
