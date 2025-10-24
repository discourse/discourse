import { getOwner } from "@ember/owner";
import { click, settled, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { setDefaultHomepage } from "discourse/lib/utilities";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Dynamic homepage handling", function () {
  test("it works when set to latest", async function (assert) {
    const router = getOwner(this).lookup("service:router");

    function assertOnLatest(path) {
      assert.strictEqual(
        router.currentRouteName,
        "discovery.latest",
        "is on latest route"
      );
      assert.strictEqual(router.currentURL, path, `path is ${path}`);
      assert
        .dom(".nav-item_latest a")
        .hasClass("active", "discovery-latest is displayed");
    }

    await visit("/");
    assertOnLatest("/");

    await click("#site-logo");
    assertOnLatest("/");

    await router.transitionTo("/").followRedirects();
    await settled();
    assertOnLatest("/");

    await router.transitionTo("discovery.index").followRedirects();
    await settled();
    assertOnLatest("/");

    await click(".nav-item_latest a");
    assertOnLatest("/latest");

    await visit("/?order=posts");
    assertOnLatest("/?order=posts");
    assert
      .dom("th.posts.sortable")
      .hasClass("sorting", "query params are passed through");
  });

  test("it works when set to categories", async function (assert) {
    setDefaultHomepage("categories");

    const router = getOwner(this).lookup("service:router");

    function assertOnCategories(path) {
      assert.strictEqual(
        router.currentRouteName,
        "discovery.categories",
        "is on categories route"
      );
      assert.strictEqual(router.currentURL, path, `path is ${path}`);
      assert
        .dom(".nav-item_categories a")
        .hasClass("active", "discovery-categories is displayed");
    }

    await visit("/");
    assertOnCategories("/");

    await click("#site-logo");
    assertOnCategories("/");

    await router.transitionTo("/").followRedirects();
    await settled();
    assertOnCategories("/");

    await router.transitionTo("discovery.index").followRedirects();
    await settled();
    assertOnCategories("/");

    await click(".nav-item_categories a");
    assertOnCategories("/categories");
  });

  test("it passes query params through", async function (assert) {
    await visit("/?test-one=true");

    const router = getOwner(this).lookup("service:router");
    assert.strictEqual(router.currentURL, "/?test-one=true");
  });

  test("it removes the _discourse_homepage_rewrite param from the URL", async function (assert) {
    await visit("/?_discourse_homepage_rewrite=1&test-one=true");

    const router = getOwner(this).lookup("service:router");
    assert.strictEqual(router.currentURL, "/?test-one=true");
  });
});
