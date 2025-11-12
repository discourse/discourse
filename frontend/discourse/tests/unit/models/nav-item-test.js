import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import Category from "discourse/models/category";
import NavItem from "discourse/models/nav-item";

module("Unit | Model | nav-item", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    const store = getOwner(this).lookup("service:store");
    const fooCategory = store.createRecord("category", {
      slug: "foo",
      id: 123,
    });
    const site = getOwner(this).lookup("service:site");
    site.categories.addObject(fooCategory);
  });

  test("href", function (assert) {
    function href(text, opts, expected, label) {
      assert.strictEqual(NavItem.fromText(text, opts).href, expected, label);
    }

    href("latest", {}, "/latest", "latest");
    href("categories", {}, "/categories", "categories");
    href("latest", { tagId: "bar" }, "/tag/bar/l/latest", "latest with tag");
    href(
      "latest",
      { tagId: "bar", category: Category.findBySlugPath(["foo"]) },
      "/tags/c/foo/123/bar/l/latest",
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
