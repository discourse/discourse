import { settled } from "@ember/test-helpers";
import { setupTest } from "ember-qunit";
import { applyInlineOneboxes } from "pretty-text/inline-oneboxer";
import { module, test } from "qunit";
import { ajax } from "discourse/lib/ajax";
import pretender, { response } from "discourse/tests/helpers/create-pretender";

module("Unit | Pretty Text | Inline Oneboxer", function (hooks) {
  setupTest(hooks);

  let links;
  hooks.beforeEach(function () {
    links = {};
    for (let i = 0; i < 11; i++) {
      const url = `http://example.com/url-${i}`;
      links[url] = document.createElement("DIV");
    }
  });

  hooks.afterEach(function () {
    links = {};
  });

  test("batches requests when oneboxing more than 10 urls", async function (assert) {
    const requestedUrls = [];
    let requestCount = 0;

    pretender.get("/inline-onebox", async (request) => {
      requestCount++;
      requestedUrls.push(...request.queryParams.urls);
      return response(200, { "inline-oneboxes": [] });
    });

    applyInlineOneboxes(links, ajax);
    await settled();

    assert.strictEqual(
      requestCount,
      2,
      "it splits the 11 urls into 2 requests"
    );
    assert.deepEqual(requestedUrls, [
      "http://example.com/url-0",
      "http://example.com/url-1",
      "http://example.com/url-2",
      "http://example.com/url-3",
      "http://example.com/url-4",
      "http://example.com/url-5",
      "http://example.com/url-6",
      "http://example.com/url-7",
      "http://example.com/url-8",
      "http://example.com/url-9",
      "http://example.com/url-10",
    ]);
  });
});
