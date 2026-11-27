import { settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import GifSearch from "discourse/lib/gif-search";

function response(title, next = "") {
  return {
    ok: true,
    json: async () => ({
      next,
      results: [
        {
          title,
          media_formats: { gif: { url: `/${title}.gif`, dims: [200, 150] } },
        },
      ],
    }),
  };
}

module("Unit | Lib | gif-search", function (hooks) {
  hooks.beforeEach(function () {
    this.requests = [];
    this.fetch = sinon.stub(window, "fetch").callsFake(
      (url) =>
        new Promise((resolve, reject) => {
          this.requests.push({ url, resolve, reject });
        })
    );
    this.dialog = { alert: sinon.spy() };
    this.search = new GifSearch({
      siteSettings: { klipy_file_detail: "gif" },
      dialog: this.dialog,
    });
  });

  hooks.afterEach(function () {
    this.search.destroy();
    sinon.restore();
  });

  test("clearing an in-flight query discards its results and pagination", async function (assert) {
    this.search.query = "parrot";
    const request = this.search.search();
    this.search.clearQuery();
    assert.false(
      this.search.loading,
      "clear stops the obsolete loading state immediately"
    );
    this.requests[0].resolve(response("parrot", "next-page"));
    await request;
    assert.strictEqual(this.search.query, "");
    assert.strictEqual(this.search.currentGifs.length, 0);
    assert.strictEqual(this.search.offset, 0);
    assert.true(this.search.hasMore);
    await settled();
    assert.strictEqual(
      this.requests.length,
      1,
      "clear does not schedule a search"
    );
  });

  test("shortening a query ignores a late failure", async function (assert) {
    this.search.query = "parrot";
    const request = this.search.search();
    this.search.refresh("pa");
    this.requests[0].reject(new Error("obsolete failure"));
    await request;
    await settled();
    assert.false(this.dialog.alert.called);
    assert.false(this.search.loading);
    assert.false(this.search.searchPending);
    assert.strictEqual(this.requests.length, 1);
  });

  test("invalidates the old query before the replacement debounce fires", async function (assert) {
    this.search.query = "parrot";
    const first = this.search.search();
    this.search.refresh("kittens");
    this.requests[0].resolve(response("parrot"));
    await first;
    assert.strictEqual(
      this.search.currentGifs.length,
      0,
      "old results cannot appear under the new query"
    );
    assert.true(this.search.searchPending);
    await this.search.loadMore();
    assert.strictEqual(
      this.requests.length,
      1,
      "pagination cannot bypass a pending replacement search"
    );
    await settled();
    assert.true(this.requests[1].url.includes("q=kittens"));
    this.requests[1].resolve(response("kittens"));
    await settled();
    assert.strictEqual(this.search.currentGifs[0].title, "kittens");
  });

  test("an obsolete request cannot stop the replacement loading indicator", async function (assert) {
    this.search.query = "parrot";
    const first = this.search.search();
    this.search.query = "kittens";
    const second = this.search.search();
    this.requests[0].resolve(response("parrot"));
    await first;
    assert.true(this.search.loading);
    this.requests[1].resolve(response("kittens"));
    await second;
    assert.false(this.search.loading);
    assert.strictEqual(this.search.currentGifs[0].title, "kittens");
  });

  test("selecting a category cancels a queued text search", async function (assert) {
    this.search.refresh("parrot");
    this.search.selectCategory({ searchterm: "party" });
    this.requests[0].resolve(response("party"));
    await settled();
    assert.strictEqual(this.requests.length, 1);
    assert.true(this.requests[0].url.includes("q=party"));
    assert.strictEqual(this.search.currentGifs[0].title, "party");
  });

  test("clearing cancels a queued search", async function (assert) {
    this.search.refresh("parrot");
    this.search.clearQuery();
    await settled();
    assert.strictEqual(this.requests.length, 0);
    assert.false(this.search.searchPending);
  });

  test("clearing during pagination cannot restore the previous result set", async function (assert) {
    this.search.query = "parrot";
    const first = this.search.search();
    this.requests[0].resolve(response("parrot", "page2"));
    await first;
    const more = this.search.loadMore();
    assert.true(this.requests[1].url.includes("pos=page2"));
    this.search.clearQuery();
    this.requests[1].resolve(response("another parrot"));
    await more;
    assert.strictEqual(this.search.currentGifs.length, 0);
    assert.strictEqual(this.search.offset, 0);
  });

  test("destroy cancels the debounce and ignores an in-flight response", async function (assert) {
    this.search.query = "parrot";
    const request = this.search.search();
    this.search.refresh("kittens");
    this.search.destroy();
    this.requests[0].resolve(response("parrot"));
    await request;
    await settled();
    assert.strictEqual(this.requests.length, 1);
    assert.strictEqual(this.search.currentGifs.length, 0);
    assert.false(this.search.loading);
    assert.false(this.dialog.alert.called);
  });
});
