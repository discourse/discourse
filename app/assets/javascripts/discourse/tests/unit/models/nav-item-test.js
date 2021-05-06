import { module, test } from "qunit";
import Category from "discourse/models/category";
import NavItem from "discourse/models/nav-item";
import Site from "discourse/models/site";
import createStore from "discourse/tests/helpers/create-store";
import { run } from "@ember/runloop";

module("Unit | Model | nav-item", function (hooks) {
  hooks.beforeEach(function () {
    run(function () {
      const fooCategory = Category.create({
        slug: "foo",
        id: 123,
      });
      Site.currentProp("categories").addObject(fooCategory);
    });
  });

  test("href", function (assert) {
    assert.expect(4);

    function href(text, opts, expected, label) {
      assert.equal(NavItem.fromText(text, opts).get("href"), expected, label);
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
    const navItem = createStore().createRecord("nav-item", { name: "new" });

    assert.equal(navItem.get("count"), 0, "it has no count by default");

    const tracker = navItem.get("topicTrackingState");
    tracker.modifyState("t1", {
      topic_id: 1,
      last_read_post_number: null,
      created_in_new_period: true,
    });
    tracker.incrementMessageCount();

    assert.equal(
      navItem.get("count"),
      1,
      "it updates when a new message arrives"
    );
  });
});
