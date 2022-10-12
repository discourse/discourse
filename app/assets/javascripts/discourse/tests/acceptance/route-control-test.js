import {
  acceptance,
  exists,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { extraConnectorClass } from "discourse/lib/plugin-connectors";
import { hbs } from "ember-cli-htmlbars";

const PREFIX = "javascripts/single-test/connectors";

acceptance("Route Control (as visitor)", function (needs) {
  needs.settings({
    top_menu: "latest|categories|top|bookmarks",
  });
  needs.hooks.beforeEach(() => {
    extraConnectorClass("below-site-header/hello");

    // eslint-disable-next-line no-undef
    Ember.TEMPLATES[`${PREFIX}/below-site-header/hello`] = hbs`
    <RouteControl @showOn="discovery.categories">
      <h1 id="only-category-page">This should only show on the category page</h1>
    </RouteControl>
    <RouteControl @showOn="homepage">
      <h1 id="only-homepage">This should only show on the homepage</h1>
    </RouteControl>
    <RouteControl @showOn="discovery.latest" @options={{hash requireUser=true}}>
      <h1 id="only-users">Only users can see this</h1>
    </RouteControl>`;
  });

  test("Category content only shows on category page", async function (assert) {
    await visit("/categories");
    assert.ok(
      exists(
        "#only-category-page",
        "The content is shown on the category page."
      )
    );
    await visit("/latest");
    assert.ok(
      !exists(
        "#only-category-page",
        "The content is not shown on the latest page."
      )
    );
  });

  test("Homepage Content only shows on all homepage routes", async function (assert) {
    await visit("/");
    assert.ok(
      exists("#only-homepage", "The content is shown on the homepage.")
    );

    await visit("/categories");
    assert.ok(
      exists("#only-homepage", "The content is shown on a homepage route.")
    );

    await visit("/t/internationalization-localization/280");
    assert.ok(
      !exists(
        "#only-homepage",
        "The content is not shown on the categories page."
      )
    );
  });

  test("User only content doesn't show for visitors", async function (assert) {
    await visit("/latest");
    assert.ok(!exists("#only-users"), "The content is not shown for visitors.");
  });
});

acceptance("Route Control (as user)", function (needs) {
  needs.user();
  needs.settings({
    top_menu: "latest|categories|top|bookmarks",
  });
  needs.hooks.beforeEach(() => {
    extraConnectorClass("below-site-header/hello");

    // eslint-disable-next-line no-undef
    Ember.TEMPLATES[`${PREFIX}/below-site-header/hello`] = hbs`
    <RouteControl @showOn="discovery.latest" @options={{hash requireUser=true}}>
      <h1 id="only-users">Only users can see this</h1>
    </RouteControl>
    <RouteControl @showOn="homepage" @options={{hash minTrustLevel=3 }}>
     <h1 id="only-trust-level">This should only show for 3 or above trust level</h1>
    </RouteControl>
`;
  });

  test("User only content shows for users", async function (assert) {
    await visit("/latest");
    assert.ok(exists("#only-users"), "The content is visible for users.");
  });

  test("Content shows for trust level 3 user", async function (assert) {
    await visit("/");
    assert.ok(
      exists("#only-trust-level"),
      "The content is visible for adequate trust level user."
    );
  });

  test("Content doesn't show for trust level 2 user", async function (assert) {
    updateCurrentUser({ trust_level: 2 });
    await visit("/");

    assert.ok(
      !exists("#only-trust-level"),
      "The content is not shown for low trust level user."
    );
  });
});
