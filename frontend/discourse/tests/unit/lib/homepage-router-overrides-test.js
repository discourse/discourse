import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import applyRouterHomepageOverrides, {
  discoveryHomepageRoute,
  homepageDestination,
  homepageNavigationDestination,
  homepagePath,
  homepagePreviewDestination,
} from "discourse/lib/homepage-router-overrides";
import { setDefaultHomepage } from "discourse/lib/utilities";
import Site from "discourse/models/site";
import { logIn } from "discourse/tests/helpers/qunit-helpers";

module("Unit | Lib | homepage-router-overrides", function (hooks) {
  setupTest(hooks);

  hooks.afterEach(function () {
    Site.current().set("homepage_options", []);
  });

  test("uses the conventional filter path for core homepages", function (assert) {
    setDefaultHomepage("latest");

    assert.strictEqual(homepagePath(), "/latest");
    assert.strictEqual(homepageNavigationDestination(), "discovery.latest");
    assert.strictEqual(homepagePreviewDestination(), "discovery.latest");
    assert.strictEqual(
      homepageDestination(),
      "/latest?_discourse_homepage_rewrite=1"
    );
  });

  test("uses the path supplied by a registered homepage", function (assert) {
    Site.current().set("homepage_options", [
      { id: "directory", path: "/directory" },
    ]);
    setDefaultHomepage("directory");

    assert.strictEqual(homepagePath(), "/directory");
    assert.strictEqual(homepageNavigationDestination(), "/directory");
    assert.strictEqual(homepagePreviewDestination(), "/directory");
    assert.strictEqual(
      homepageDestination(),
      "/directory?_discourse_homepage_rewrite=1"
    );
  });

  test("returns the site root for a server-rendered homepage", function (assert) {
    Site.current().set("homepage_options", [
      { id: "directory", path: "/directory", server_side: true },
    ]);
    setDefaultHomepage("directory");

    assert.strictEqual(homepagePath(), "/directory");
    assert.strictEqual(homepageDestination(), "/");
    assert.strictEqual(homepageNavigationDestination(), "/");
    assert.strictEqual(homepagePreviewDestination(), "discovery.latest");
  });

  test("uses the homepage for topic lists when it is a discovery route", function (assert) {
    setDefaultHomepage("categories");

    assert.strictEqual(discoveryHomepageRoute(), "discovery.categories");
  });

  test("falls back to the top menu for topic lists when a registered homepage is active", function (assert) {
    Site.current().set("homepage_options", [
      { id: "directory", path: "/directory" },
    ]);
    this.owner.lookup("service:site-settings").top_menu =
      "new|categories|latest";
    setDefaultHomepage("directory");

    assert.strictEqual(
      discoveryHomepageRoute(),
      "discovery.categories",
      "skips top menu items anonymous visitors cannot see"
    );

    logIn(this.owner);

    assert.strictEqual(discoveryHomepageRoute(), "discovery.new");
  });

  test("keeps `/` when a registered homepage shown there updates its own URL", function (assert) {
    Site.current().set("homepage_options", [
      { id: "directory", path: "/directory" },
    ]);
    setDefaultHomepage("directory");

    let currentURL = "/";
    const updatedURLs = [];
    const microLib = {
      activeTransition: null,
      updateURL: (url) => updatedURLs.push(url),
      replaceURL: (url) => updatedURLs.push(url),
    };
    applyRouterHomepageOverrides({
      location: { getURL: () => currentURL },
      // eslint-disable-next-line ember/no-private-routing-service
      _routerMicrolib: microLib,
    });

    microLib.replaceURL("/directory?sort=name");
    currentURL = "/latest";
    microLib.updateURL("/directory");

    assert.deepEqual(updatedURLs, ["/?sort=name", "/directory"]);
  });
});
