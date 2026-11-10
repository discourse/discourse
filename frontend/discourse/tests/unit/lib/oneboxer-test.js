import { settled } from "@ember/test-helpers";
import { setupTest } from "ember-qunit";
import { load } from "pretty-text/oneboxer";
import { failedCache, localCache } from "pretty-text/oneboxer-cache";
import { module, test } from "qunit";
import { ajax } from "discourse/lib/ajax";

function loadOnebox(element) {
  return load({
    elem: element,
    refresh: false,
    ajax,
    synchronous: true,
    categoryId: 1,
    topicId: 1,
  });
}

module("Unit | Utility | oneboxer", function (hooks) {
  setupTest(hooks);

  test("load - failed onebox", async function (assert) {
    let element = document.createElement("A");
    element.setAttribute("href", "http://somebadurl.com");

    await loadOnebox(element);

    assert.true(
      failedCache["http://somebadurl.com"],
      "stores the url as failed in a cache"
    );
    assert.strictEqual(
      loadOnebox(element),
      undefined,
      "returns early for a failed cache"
    );
  });

  test("load - successful onebox", async function (assert) {
    let element = document.createElement("A");
    element.setAttribute("href", "http://somegoodurl.com");

    await loadOnebox(element);

    assert.true(
      localCache["http://somegoodurl.com"].outerHTML.includes(
        "Yet another collaboration tool"
      ),
      "stores the html of the onebox in a local cache"
    );
    assert.true(
      loadOnebox(element).includes("Yet another collaboration tool"),
      "returns the html from the cache"
    );
  });

  test("load - does not refetch a url an earlier queued entry resolved", async function (assert) {
    let requests = 0;
    const countingAjax = (...args) => {
      requests++;
      return ajax(...args);
    };

    for (let i = 0; i < 2; i++) {
      const element = document.createElement("A");
      element.setAttribute("href", "http://somegoodurl.com");
      load({ elem: element, refresh: false, ajax: countingAjax });
    }
    await settled();

    assert.strictEqual(requests, 1);
  });
});
