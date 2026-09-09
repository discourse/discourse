import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import {
  homepageDestination,
  homepageNavigationDestination,
  homepagePath,
  homepagePreviewDestination,
} from "discourse/lib/homepage-router-overrides";
import { setDefaultHomepage } from "discourse/lib/utilities";
import Site from "discourse/models/site";

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
});
