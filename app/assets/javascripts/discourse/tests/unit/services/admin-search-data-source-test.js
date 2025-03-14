import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import PreloadStore from "discourse/lib/preload-store";
import { ADMIN_NAV_MAP } from "discourse/lib/sidebar/admin-nav-map";

function fabricateVisiblePlugins() {
  return [
    {
      admin_route: {
        auto_generated: false,
        full_location: "adminPlugins.show",
        label: "chat.admin.title",
        location: "chat",
        use_new_show_route: true,
      },
      description:
        "Adds chat functionality to your site so it can natively support both long-form and short-form communication needs of your online community",
      enabled: true,
      name: "chat",
      humanized_name: "Chat",
    },
    {
      name: "discourse-new-features-feeds",
      humanized_name: "New features feeds",
      admin_route: {
        location: "discourse-new-features-feeds",
        label: "new_feature_feeds.sidebar_plugin_name",
        use_new_show_route: true,
        auto_generated: false,
        full_location: "adminPlugins.show",
      },
      enabled: true,
      description:
        "Create feeds for new feature notices consumed by other Discourse instances.",
    },
    {
      name: "discourse-calendar",
      humanized_name: "Calendar",
      enabled: false,
      description:
        "Adds the ability to create a dynamic calendar with events in a topic.",
    },
    {
      name: "badplugin",
      humanized_name: "Badplugin",
      admin_route: {
        location: "blahblahnogood",
        label: "badplugin.title",
        use_new_show_route: true,
        auto_generated: true,
        full_location: "somemesseduproute",
      },
      enabled: true,
      description: "Does things",
    },
  ];
}

module("Unit | Service | AdminSearchDataSource", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.subject = getOwner(this).lookup("service:admin-search-data-source");
  });

  test("buildMap - is a noop if already cached", async function (assert) {
    await this.subject.buildMap();
    sinon.stub(ADMIN_NAV_MAP, "forEach");
    await this.subject.buildMap();
    assert.false(ADMIN_NAV_MAP.forEach.called);
  });

  test("buildMap - makes a key/value object of preloaded plugins, excluding disabled and invalid ones", async function (assert) {
    PreloadStore.store("visiblePlugins", fabricateVisiblePlugins());
    await this.subject.buildMap();
    assert.deepEqual(Object.keys(this.subject.plugins), [
      "chat",
      "discourse-new-features-feeds",
    ]);
    assert.deepEqual(
      this.subject.plugins["chat"],
      fabricateVisiblePlugins()[0]
    );
  });

  test("buildMap - uses ADMIN_NAV_MAP to build up a list of page links including sub-pages", async function (assert) {
    await this.subject.buildMap();

    assert.true(this.subject.pageMapItems.length > ADMIN_NAV_MAP.length);

    assert.deepEqual(this.subject.pageMapItems[0], {
      label: "Dashboard",
      url: "/admin",
      keywords:
        " /admin dashboard the dashboard provides a snapshot of your community’s health, including traffic, user activity, and other key metrics",
      type: "page",
      icon: "house",
      description:
        "The dashboard provides a snapshot of your community’s health, including traffic, user activity, and other key metrics",
    });

    assert.notStrictEqual(
      this.subject.pageMapItems.find(
        (page) => page.url === "/admin/backups/logs"
      ),
      null
    );
  });
});
