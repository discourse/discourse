import { destroy } from "@ember/destroyable";
import { getOwner } from "@ember/owner";
import { run } from "@ember/runloop";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { addUniqueValueToArray } from "discourse/lib/array-tools";
import Category from "discourse/models/category";
import NavItem, { addNavItem, clearNavItems } from "discourse/models/nav-item";

module("Unit | Model | nav-item", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    const store = getOwner(this).lookup("service:store");
    const fooCategory = store.createRecord("category", {
      slug: "foo",
      id: 123,
    });
    const site = getOwner(this).lookup("service:site");
    addUniqueValueToArray(site.categories, fooCategory);
  });

  test("href", function (assert) {
    function href(text, opts, expected, label) {
      assert.strictEqual(NavItem.fromText(text, opts).href, expected, label);
    }

    href("latest", {}, "/latest", "latest");
    href("categories", {}, "/categories", "categories");
    href(
      "latest",
      { tag: { id: 1, name: "bar", slug: "bar" } },
      "/tag/bar/1/l/latest",
      "latest with tag"
    );
    href(
      "latest",
      {
        tag: { id: 1, name: "bar", slug: "bar" },
        category: Category.findBySlugPath(["foo"]),
      },
      "/tags/c/foo/123/bar/1/l/latest",
      "latest with tag and category"
    );
  });

  test("count", function (assert) {
    const store = getOwner(this).lookup("service:store");
    const navItem = store.createRecord("nav-item", { name: "new" });

    assert.strictEqual(navItem.count, 0, "it has no count by default");

    navItem.topicTrackingState.modifyState("t1", {
      topic_id: 1,
      last_read_post_number: null,
      created_in_new_period: true,
    });
    navItem.topicTrackingState.messageCount++;

    assert.strictEqual(
      navItem.count,
      1,
      "it updates when a new message arrives"
    );
  });

  test("displayName", function (assert) {
    const store = getOwner(this).lookup("service:store");
    const navItem = store.createRecord("nav-item", {
      name: "something",
    });

    assert.strictEqual(
      navItem.displayName,
      "[en.filters.something.title count=0]"
    );

    navItem.set("displayName", "Extra Item");
    assert.strictEqual(navItem.displayName, "Extra Item");
  });

  test("title", function (assert) {
    const store = getOwner(this).lookup("service:store");
    const navItem = store.createRecord("nav-item", {
      name: "something",
    });

    assert.strictEqual(navItem.title, "[en.filters.something.help]");

    navItem.set("title", "Extra Item");
    assert.strictEqual(navItem.title, "Extra Item");
  });
});

module("Unit | Model | nav-item | owner lifetime", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.firstOwner = {};
    this.secondOwner = {};
  });

  hooks.afterEach(function () {
    run(() => {
      destroy(this.firstOwner);
      destroy(this.secondOwner);
    });
    clearNavItems();
  });

  test("old owner cleanup preserves a descriptor registered after reset", function (assert) {
    const item = { name: "owner-lifetime", href: "/latest" };
    const siteSettings = this.owner.lookup("service:site-settings");
    addNavItem(item, { owner: this.firstOwner });
    clearNavItems();
    addNavItem(item, { owner: this.secondOwner });

    run(() => destroy(this.firstOwner));

    assert.true(
      NavItem.buildList(null, { siteSettings }).some(
        (entry) => entry.name === "owner-lifetime"
      ),
      "the replacement registration still contributes a navigation item"
    );

    run(() => destroy(this.secondOwner));

    assert.false(
      NavItem.buildList(null, { siteSettings }).some(
        (entry) => entry.name === "owner-lifetime"
      ),
      "destroying its own owner removes the navigation item"
    );
  });

  test("removing the last duplicate preserves ordering and live descriptor changes", function (assert) {
    const shared = { name: "owner-shared", href: "/latest" };
    const middle = { name: "owner-middle", href: "/categories" };
    const siteSettings = this.owner.lookup("service:site-settings");
    const items = () =>
      NavItem.buildList(null, { siteSettings })
        .filter((item) => item.name.startsWith("owner-"))
        .map((item) => [item.name, item.href]);
    addNavItem(shared, { owner: this.firstOwner });
    addNavItem(middle);
    addNavItem(shared, { owner: this.secondOwner });

    assert.deepEqual(
      items(),
      [
        ["owner-shared", "/latest"],
        ["owner-middle", "/categories"],
        ["owner-shared", "/latest"],
      ],
      "both registrations appear in their original positions"
    );

    run(() => destroy(this.secondOwner));
    shared.href = "/top";

    assert.deepEqual(
      items(),
      [
        ["owner-shared", "/top"],
        ["owner-middle", "/categories"],
      ],
      "the first registration stays before the middle item and reflects mutation"
    );
  });
});
