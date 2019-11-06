import { run } from "@ember/runloop";
import createStore from "helpers/create-store";

QUnit.module("Discourse.NavItem", {
  beforeEach() {
    run(function() {
      const asianCategory = Discourse.Category.create({
        name: "确实是这样",
        id: 343434
      });
      Discourse.Site.currentProp("categories").addObject(asianCategory);
    });
  }
});

QUnit.test("href", assert => {
  assert.expect(4);

  function href(text, expected, label) {
    assert.equal(
      Discourse.NavItem.fromText(text, {}).get("href"),
      expected,
      label
    );
  }

  href("latest", "/latest", "latest");
  href("categories", "/categories", "categories");
  href("category/bug", "/c/bug", "English category name");
  href("category/确实是这样", "/c/343434-category", "Chinese category name");
});

QUnit.test("count", assert => {
  const navItem = createStore().createRecord("nav-item", { name: "new" });

  assert.equal(navItem.get("count"), 0, "it has no count by default");

  const tracker = navItem.get("topicTrackingState");
  tracker.states["t1"] = { topic_id: 1, last_read_post_number: null };
  tracker.incrementMessageCount();

  assert.equal(
    navItem.get("count"),
    1,
    "it updates when a new message arrives"
  );
});
