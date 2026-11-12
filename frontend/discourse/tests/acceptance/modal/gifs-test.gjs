import { getOwner } from "@ember/owner";
import { click, fillIn, find, settled, visit } from "@ember/test-helpers";
import { test } from "qunit";
import sinon from "sinon";
import GifsModal from "discourse/components/modal/gifs";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import stubIntersectionObserver from "discourse/tests/helpers/stub-intersection-observer";
import {
  disableLoadMoreObserver,
  enableLoadMoreObserver,
} from "discourse/ui-kit/d-load-more";

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
      .find((call) => call.args[0].includes("/gifs/categories.json"));
    assert.notStrictEqual(
      categoriesCall,
      undefined,
      "called the GIF categories proxy"
    );
    assert.false(
      categoriesCall.args[0].includes("key="),
      "does not pass an API key in the query"
    );
  });

  test("search triggers a Klipy fetch with the query", async function (assert) {
    fetchStub.callsFake(async (url) => {
      if (url.includes("/gifs/categories.json")) {
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
      .find((call) => call.args[0].includes("/gifs/search.json"));

    assert.notStrictEqual(searchCall, undefined, "called the GIF search proxy");
    assert.true(searchCall.args[0].includes("q=hello"), "passes the query");
    assert.false(
      searchCall.args[0].includes("key="),
      "does not pass an API key in the query"
    );
    assert
      .dom(".gifs-modal .gifs-result")
      .exists({ count: 1 }, "renders the result returned by Klipy");
  });

  test("intersecting the sentinel in the modal loads the next page of GIFs", async function (assert) {
    const observations = stubIntersectionObserver();
    const results = [gif("first GIF", "/images/emoji/twitter/smile.png")];
    const positions = [];

    fetchStub.callsFake(async (url) => {
      if (url.includes("/gifs/categories.json")) {
        return categoriesResponse();
      }

      const position = new URL(url, window.location.origin).searchParams.get(
        "pos"
      );
      positions.push(position);
      return position === "0"
        ? searchResponse({ results, next: "next-page" })
        : searchResponse({ results: [gif("last GIF")] });
    });

    enableLoadMoreObserver();

    try {
      await visit("/");
      getOwner(this).lookup("service:modal").show(GifsModal);
      await settled();
      await fillIn(".gifs-modal input[name=query]", "hello");

      const sentinel = () =>
        observations.findLast(
          ({ element }) => element === find(".gifs-modal .load-more-sentinel")
        );
      assert.strictEqual(
        sentinel().options.root,
        find(".gifs-modal .d-modal__body"),
        "observes the sentinel within the scrollable modal body"
      );

      assert.deepEqual(
        positions,
        ["0"],
        "only fetches the first page initially"
      );

      await sentinel().trigger();

      assert.deepEqual(
        positions,
        ["0", "next-page"],
        "uses the pagination cursor"
      );
      assert
        .dom(".gifs-modal .gifs-result")
        .exists({ count: 2 }, "appends the next page to the existing results");

      await sentinel().trigger();
      assert.strictEqual(positions.length, 2, "stops after the last page");
    } finally {
      disableLoadMoreObserver();
    }
  });

  test("picking a result invokes customPickHandler with markup", async function (assert) {
    fetchStub.callsFake(async (url) => {
      if (url.includes("/gifs/categories.json")) {
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
      if (url.includes("/gifs/categories.json")) {
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
