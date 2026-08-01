import { click, fillIn, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import GifPanel from "discourse/components/composer-picker/gif-panel";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

function fetchResponse(body) {
  return { ok: true, status: 200, json: async () => body };
}

const PARROT = {
  title: "party parrot",
  media_formats: {
    gif: { url: "https://klipy.example/parrot.gif", dims: [200, 150] },
  },
};

module("Integration | Component | composer-picker/gif-panel", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.siteSettings.enable_gifs = true;
    this.siteSettings.klipy_file_detail = "gif";

    this.fetchStub = sinon.stub(window, "fetch").callsFake(async (url) => {
      if (url.includes("/gifs/categories")) {
        return fetchResponse({ tags: [] });
      }
      return fetchResponse({ results: [PARROT], next: "" });
    });
  });

  test("typing a query searches through the backend and renders results", async function (assert) {
    await render(<template><GifPanel @context="topic" /></template>);

    await fillIn(".gif-panel__filter input", "parrot");

    const searchCall = this.fetchStub
      .getCalls()
      .find((c) => c.args[0].includes("/gifs/search"));

    assert.true(
      searchCall?.args[0].includes("q=parrot"),
      "queries the backend endpoint with the typed term"
    );
    assert
      .dom(".gif-panel .gifs-result")
      .exists({ count: 1 }, "renders the returned GIF");
  });

  test("picking a result forwards the gif markup to onSelect", async function (assert) {
    let received;
    const onSelect = (value) => (received = value);

    await render(
      <template><GifPanel @context="topic" @onSelect={{onSelect}} /></template>
    );

    await fillIn(".gif-panel__filter input", "parrot");
    await click(".gif-panel .gifs-result");

    assert.strictEqual(
      received,
      "\n![party parrot|200x150](https://klipy.example/parrot.gif)\n",
      "onSelect receives the gif markdown"
    );
  });

  test("fetches featured categories when opened", async function (assert) {
    await render(<template><GifPanel @context="topic" /></template>);

    const categoriesCall = this.fetchStub
      .getCalls()
      .find((c) => c.args[0].includes("/gifs/categories"));

    assert.notStrictEqual(
      categoriesCall,
      undefined,
      "requests featured categories from the backend on open"
    );
  });

  test("shows the no-results state when the search is empty", async function (assert) {
    this.fetchStub.callsFake(async (url) => {
      if (url.includes("/gifs/categories")) {
        return fetchResponse({ tags: [] });
      }
      return fetchResponse({ results: [], next: "" });
    });

    await render(<template><GifPanel @context="topic" /></template>);
    await fillIn(".gif-panel__filter input", "nothingmatches");

    assert
      .dom(".gif-panel__no-results")
      .exists("renders the no-results message");
  });
});
