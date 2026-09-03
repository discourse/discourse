import { click, render, triggerEvent, waitUntil } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import CategoryCardContents from "discourse/components/category-card-contents";
import { forceMobile } from "discourse/lib/mobile";
import DiscourseURL from "discourse/lib/url";
import Category from "discourse/models/category";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";

module("Integration | Component | CategoryCardContents", function (hooks) {
  setupRenderingTest(hooks);

  test("opens from a category hashtag and closes on an outside click", async function (assert) {
    await render(
      <template>
        <div id="main-outlet">
          <a
            class="hashtag-cooked"
            data-id="2"
            data-type="category"
            href="/c/product/2"
          >#product</a>
        </div>
        <CategoryCardContents />
      </template>
    );

    await click('a.hashtag-cooked[data-type="category"]');

    assert.dom(".category-card .card-content").exists("the card opens");

    await triggerEvent("#main-outlet", "pointerdown");

    assert.dom(".category-card .card-content").doesNotExist("the card closes");
  });

  test("lazy loads a category outside a post and reuses it on reopening", async function (assert) {
    this.site.set("lazy_load_categories", true);
    const requestedIds = [];

    pretender.get("/categories/find", (request) => {
      requestedIds.push(request.queryParams.ids);
      return response({
        categories: [
          { id: 12345, name: "Lazy category", slug: "lazy-category" },
        ],
      });
    });

    await render(
      <template>
        <div id="main-outlet">
          <a
            class="hashtag-cooked"
            data-id="12345"
            data-type="category"
            href="/c/lazy-category/12345"
          >#lazy-category</a>
        </div>
        <CategoryCardContents />
      </template>
    );

    await click('a.hashtag-cooked[data-type="category"]');

    assert.deepEqual(
      requestedIds,
      [["12345"]],
      "the hashtag ID is lazy loaded"
    );
    assert.strictEqual(
      Category.findById(12345).name,
      "Lazy category",
      "the category model is available"
    );
    assert
      .dom(".category-card .card-content")
      .exists("the card opens without a topic or post");

    await triggerEvent("#main-outlet", "pointerdown");
    await click('a.hashtag-cooked[data-type="category"]');

    assert.dom(".category-card .card-content").exists("the card reopens");
    assert.strictEqual(requestedIds.length, 1, "the loaded category is reused");
  });
});

module(
  "Integration | Component | CategoryCardContents | Anonymous",
  function (hooks) {
    setupRenderingTest(hooks, { anonymous: true });

    async function renderStaffHashtag() {
      await render(
        <template>
          <div id="main-outlet">
            <a
              class="hashtag-cooked"
              data-id="123456"
              data-type="category"
              href="/c/staff/123456"
            >#staff</a>
          </div>
          <div class="card-cloak"></div>
          <CategoryCardContents />
        </template>
      );
    }

    for (const mobileView of [false, true]) {
      for (const status of [null, 200, 403, 404]) {
        test(`navigates without opening a popup for an inaccessible category (${mobileView ? "mobile" : "desktop"}, ${status ?? "preloaded"})`, async function (assert) {
          if (mobileView) {
            forceMobile();
          }
          this.site.set("lazy_load_categories", status !== null);
          const routeTo = sinon.stub(DiscourseURL, "routeTo");

          if (status !== null) {
            pretender.get("/categories/find", () =>
              response(status, { categories: [] })
            );
          }

          await renderStaffHashtag();
          const createMenu = sinon.spy(
            this.owner.lookup("service:menu"),
            "newInstance"
          );
          await click('a.hashtag-cooked[data-type="category"]');

          assert.true(
            routeTo.calledOnceWithExactly(
              `${window.location.origin}/c/staff/123456`
            ),
            "the original category URL handles the unavailable category"
          );
          assert.false(createMenu.called, "no floating menu is ever created");
          assert
            .dom('.fk-d-menu[data-identifier="category-card"]')
            .doesNotExist("no empty popup remains");
          assert
            .dom(".category-card .card-content")
            .doesNotExist("no category content is shown");
          assert
            .dom(".card-cloak")
            .doesNotHaveClass("--visible", "no mobile cloak is shown");
        });
      }
    }

    for (const accessible of [false, true]) {
      test(`navigation during lookup does not reopen or redirect (accessible: ${accessible})`, async function (assert) {
        this.site.set("lazy_load_categories", true);
        const routeTo = sinon.stub(DiscourseURL, "routeTo");
        let releaseLookup;

        pretender.get("/categories/find", async () => {
          await new Promise((resolve) => (releaseLookup = resolve));
          return response({
            categories: accessible
              ? [{ id: 123456, name: "Staff", slug: "staff" }]
              : [],
          });
        });

        await renderStaffHashtag();
        const opening = click('a.hashtag-cooked[data-type="category"]');
        await waitUntil(() => releaseLookup);

        assert
          .dom('.fk-d-menu[data-identifier="category-card"]')
          .doesNotExist("no popup opens while access is unresolved");
        assert
          .dom(".category-card .card-content")
          .doesNotExist("no content is shown while loading");

        this.owner.lookup("service:app-events").trigger("dom:clean");
        releaseLookup();
        await opening;

        assert.false(routeTo.called, "a cancelled lookup does not navigate");
        assert
          .dom('.fk-d-menu[data-identifier="category-card"]')
          .doesNotExist("a cancelled lookup does not open a popup");
        assert
          .dom(".category-card .card-content")
          .doesNotExist("the card stays closed");
      });
    }
  }
);
