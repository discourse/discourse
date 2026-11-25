import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { isEmptyCategoryList } from "discourse/lib/empty-category";

module("Unit | Utility | empty-category", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.store = getOwner(this).lookup("service:store");
    this.category = this.store.createRecord("category", {
      id: 1,
      slug: "photography",
      topic_url: "/t/about-the-photography-category/10",
    });

    this.topic = (id, creatorId) =>
      this.store.createRecord("topic", {
        id,
        posters: [{ user: { id: creatorId } }],
      });

    this.list = (topics, props = {}) => ({
      filter: "c/photography/1/l/latest",
      topics,
      ...props,
    });
  });

  test("is empty with no topics", function (assert) {
    assert.true(
      isEmptyCategoryList({ category: this.category, list: this.list([]) })
    );
  });

  test("ignores the category's About topic", function (assert) {
    const list = this.list([this.topic(10, 5)]);

    assert.true(isEmptyCategoryList({ category: this.category, list }));
  });

  test("is not empty once a system or bot account starts a topic", function (assert) {
    const list = this.list([this.topic(10, 5), this.topic(11, -1)]);

    assert.false(isEmptyCategoryList({ category: this.category, list }));
  });

  test("is not empty once a member starts a topic", function (assert) {
    const list = this.list([this.topic(10, 5), this.topic(12, 5)]);

    assert.false(isEmptyCategoryList({ category: this.category, list }));
  });

  test("only applies to a fully loaded latest list", function (assert) {
    assert.false(
      isEmptyCategoryList({
        category: this.category,
        list: this.list([], { filter: "c/photography/1/l/top" }),
      }),
      "not on other filters"
    );

    assert.false(
      isEmptyCategoryList({
        category: this.category,
        list: this.list([], { more_topics_url: "/c/photography/1/l/latest" }),
      }),
      "not while more topics can load"
    );

    assert.false(
      isEmptyCategoryList({
        category: this.category,
        tag: { id: 1 },
        list: this.list([]),
      }),
      "not on tag-filtered lists"
    );
  });
});
