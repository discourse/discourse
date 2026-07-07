import { getOwner } from "@ember/owner";
import { click, fillIn, settled, visit } from "@ember/test-helpers";
import { test } from "qunit";
import sinon from "sinon";
import GifsModal from "discourse/components/modal/gifs";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

function fetchResponse(body) {
  return { ok: true, status: 200, json: async () => body };
}

function categoriesResponse(tags = []) {
  return fetchResponse({ tags });
}

function searchResponse({ results = [], next = "" } = {}) {
  return fetchResponse({ results, next });
}

function gif(title, url = "https://example.com/g.gif") {
  return {
    title,
    media_formats: { gif: { url, dims: [200, 150] } },
  };
}

acceptance("Modal - GIFs", function (needs) {
  needs.user();
  needs.settings({
    enable_gifs: true,
    klipy_api_key: "test-key",
    klipy_country: "US",
    klipy_locale: "en_US",
    klipy_content_filter: "high",
    klipy_file_detail: "gif",
    klipy_limit_infinite_search_results: false,
    klipy_max_results_limit: 100,
  });

  let fetchStub;

  needs.hooks.beforeEach(function () {
    fetchStub = sinon.stub(window, "fetch");
  });

  test("fetches categories when opened", async function (assert) {
    fetchStub.resolves(categoriesResponse());

    await visit("/");
    const modalService = getOwner(this).lookup("service:modal");
    modalService.show(GifsModal);
    await settled();

    assert.dom(".gifs-modal").exists("renders the modal");
    assert
      .dom(".gifs-modal__branding")
      .exists("always shows the Klipy branding");

    const categoriesCall = fetchStub
      .getCalls()
      .find((c) => c.args[0].includes("/v2/categories"));
    assert.notStrictEqual(
      categoriesCall,
      undefined,
      "called the Klipy categories endpoint"
    );
    assert.true(
      categoriesCall.args[0].includes("key=test-key"),
      "passes api key in query"
    );
  });

  test("search triggers a Klipy fetch with the query", async function (assert) {
    fetchStub.callsFake(async (url) => {
      if (url.includes("/v2/categories")) {
        return categoriesResponse();
      }
      return searchResponse({ results: [gif("a hello gif")] });
    });

    await visit("/");
    const modalService = getOwner(this).lookup("service:modal");
    modalService.show(GifsModal);
    await settled();

    await fillIn(".gifs-modal input[name=query]", "hello");

    const searchCall = fetchStub
      .getCalls()
      .find((c) => c.args[0].includes("/v2/search"));

    assert.notStrictEqual(
      searchCall,
      undefined,
      "called the Klipy search endpoint"
    );
    assert.true(searchCall.args[0].includes("q=hello"), "passes the query");
    assert
      .dom(".gifs-modal .gifs-result")
      .exists({ count: 1 }, "renders the result returned by Klipy");
  });

  test("picking a result invokes customPickHandler with markup", async function (assert) {
    fetchStub.callsFake(async (url) => {
      if (url.includes("/v2/categories")) {
        return categoriesResponse();
      }
      return searchResponse({
        results: [gif("party parrot", "https://klipy.example/parrot.gif")],
      });
    });

    let receivedMarkup;
    await visit("/");
    const modalService = getOwner(this).lookup("service:modal");
    const closed = modalService.show(GifsModal, {
      model: {
        customPickHandler: (markup) => {
          receivedMarkup = markup;
        },
      },
    });

    await settled();
    await fillIn(".gifs-modal input[name=query]", "party");

    await click(".gifs-modal .gifs-result");

    assert.strictEqual(
      receivedMarkup,
      "\n![party parrot|200x150](https://klipy.example/parrot.gif)\n",
      "invokes customPickHandler with the gif markup"
    );
    assert.dom(".gifs-modal").doesNotExist("closes the modal after pick");

    await closed;
  });

  test("renders a no results state when Klipy returns nothing", async function (assert) {
    fetchStub.callsFake(async (url) => {
      if (url.includes("/v2/categories")) {
        return categoriesResponse();
      }
      return searchResponse({ results: [], next: "" });
    });

    await visit("/");
    const modalService = getOwner(this).lookup("service:modal");
    modalService.show(GifsModal);
    await settled();

    await fillIn(".gifs-modal input[name=query]", "nothingmatches");

    assert
      .dom(".gifs-modal .gifs-modal__no-results")
      .exists("renders the no-results message");
  });
});
