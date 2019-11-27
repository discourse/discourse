import { load } from "pretty-text/oneboxer";
import { ajax } from "discourse/lib/ajax";
import { failedCache, localCache } from "pretty-text/oneboxer-cache";
import { stringToHTML } from "helpers/html-helper";

function loadOnebox(element) {
  return load({
    elem: element,
    refresh: false,
    ajax,
    synchronous: true,
    categoryId: 1,
    topicId: 1
  });
}

QUnit.module("lib:oneboxer");

QUnit.test("load - failed onebox", async assert => {
  let element = document.createElement("A");
  element.setAttribute("href", "http://somebadurl.com");

  // prettier-ignore
  server.get("/onebox", () => { //eslint-disable-line
    return [404, {}, {}];
  });

  await loadOnebox(element);

  assert.equal(
    failedCache["http://somebadurl.com"],
    true,
    "stores the url as failed in a cache"
  );
  assert.equal(
    loadOnebox(element),
    undefined,
    "it returns early for a failed cache"
  );
});

QUnit.test("load - successful onebox", async assert => {
  const html = `
    <aside class="onebox whitelistedgeneric">
      <header class="source">
          <a href="http://test.com/somepage" target="_blank">test.com</a>
      </header>
      <article class="onebox-body">
      <div class="aspect-image" style="--aspect-ratio:690/362;"><img src="https://test.com/image.png" class="thumbnail"></div>
      <h3><a href="http://test.com/somepage" target="_blank">Test Page</a></h3>
      <p>Yet another collaboration tool</p>
      </article>
      <div class="onebox-metadata"></div>
      <div style="clear: both"></div>
    </aside>
  `;

  // prettier-ignore
  server.get("/onebox", () => { //eslint-disable-line
    return [200, {}, html];
  });

  let element = document.createElement("A");
  element.setAttribute("href", "http://somegoodurl.com");

  await loadOnebox(element);

  assert.equal(
    localCache["http://somegoodurl.com"].prop("outerHTML"),
    stringToHTML(html).outerHTML,
    "stores the html of the onebox in a local cache"
  );
  assert.equal(
    loadOnebox(element),
    stringToHTML(html).outerHTML,
    "it returns the html from the cache"
  );
});
