import { destroy } from "@ember/destroyable";
import EmberObject from "@ember/object";
import { run } from "@ember/runloop";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import renderTags, {
  addTagsHtmlCallback,
  clearTagsHtmlCallbacks,
} from "discourse/lib/render-tags";

module("Unit | Utility | render-tags", function (hooks) {
  setupTest(hooks);

  hooks.afterEach(() => clearTagsHtmlCallbacks());

  test("renderTags with tagClasses param", function (assert) {
    const topic = EmberObject.create({
      tags: ["cat", "dog"],
      get(prop) {
        return this[prop];
      },
    });

    const tagClasses = {
      cat: "meow",
      dog: "woof",
    };

    const classResult = renderTags(topic, { tagClasses });
    const classDiv = document.createElement("div");
    classDiv.innerHTML = classResult;

    const catTagLink = classDiv.querySelector('[data-tag-name="cat"]');
    const dogTagLink = classDiv.querySelector('[data-tag-name="dog"]');

    assert.notStrictEqual(catTagLink, null, "cat tag exists");
    assert.notStrictEqual(dogTagLink, null, "dog tag exists");

    assert.true(
      catTagLink.classList.contains("meow"),
      "adds the meow class to the cat tag"
    );
    assert.true(
      dogTagLink.classList.contains("woof"),
      "adds the woof class to the dog tag"
    );
  });

  test("callback returning an array renders each item as its own li", function (assert) {
    addTagsHtmlCallback(() => ["<a>one</a>", "<a>two</a>", "<a>three</a>"]);

    const topic = EmberObject.create({
      tags: [],
      get(prop) {
        return this[prop];
      },
    });

    const result = renderTags(topic, {});
    const div = document.createElement("div");
    div.innerHTML = result;

    const items = div.querySelectorAll(".discourse-tags > li");
    assert.strictEqual(items.length, 3, "each array item gets its own li");
    assert.strictEqual(items[0].querySelector("a").textContent, "one");
    assert.strictEqual(items[1].querySelector("a").textContent, "two");
    assert.strictEqual(items[2].querySelector("a").textContent, "three");
    assert.dom(".discourse-tags__tag-separator", items[0]).exists();
    assert.dom(".discourse-tags__tag-separator", items[1]).exists();
    assert.dom(".discourse-tags__tag-separator", items[2]).doesNotExist();
  });

  test("callback returning an array alongside regular tags", function (assert) {
    addTagsHtmlCallback(() => ["<a>one</a>", "<a>two</a>"]);

    const topic = EmberObject.create({
      tags: ["alpha", "beta"],
      get(prop) {
        return this[prop];
      },
    });

    const result = renderTags(topic, {});
    const div = document.createElement("div");
    div.innerHTML = result;

    const items = div.querySelectorAll(".discourse-tags > li");
    assert.strictEqual(items.length, 4, "tags and array items each own li");
    assert.dom('[data-tag-name="alpha"]', items[0]).exists();
    assert.dom('[data-tag-name="beta"]', items[1]).exists();
    assert.strictEqual(items[2].querySelector("a").textContent, "one");
    assert.strictEqual(items[3].querySelector("a").textContent, "two");
  });
});

module("Unit | Utility | render-tags | owner lifetime", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.firstOwner = {};
    this.secondOwner = {};
    this.topic = EmberObject.create({ tags: [] });
  });

  hooks.afterEach(function () {
    run(() => {
      destroy(this.firstOwner);
      destroy(this.secondOwner);
      this.topic.destroy();
    });
    clearTagsHtmlCallbacks();
  });

  test("owner cleanup preserves duplicate callbacks and priority order", function (assert) {
    const callback = () => "<a>shared</a>";
    addTagsHtmlCallback(callback, { priority: 10 }, { owner: this.firstOwner });
    addTagsHtmlCallback(() => "<a>middle</a>", { priority: 0 });
    addTagsHtmlCallback(
      callback,
      { priority: -10 },
      { owner: this.secondOwner }
    );
    const element = document.createElement("div");
    element.innerHTML = renderTags(this.topic, {});
    assert.dom("a", element).exists({ count: 3 }, "both owners contribute");

    run(() => destroy(this.firstOwner));
    element.innerHTML = renderTags(this.topic, {});

    assert
      .dom("li:first-child a", element)
      .hasText("middle", "priority is preserved");
    assert
      .dom("li:last-child a", element)
      .hasText("shared", "the second owner survives");
    assert
      .dom("a", element)
      .exists({ count: 2 }, "only one registration was removed");
  });

  test("old owner cleanup cannot remove callbacks registered after a reset", function (assert) {
    const callback = () => "<a>shared</a>";
    addTagsHtmlCallback(callback, {}, { owner: this.firstOwner });
    clearTagsHtmlCallbacks();
    addTagsHtmlCallback(callback, {}, { owner: this.secondOwner });

    run(() => destroy(this.firstOwner));
    const element = document.createElement("div");
    element.innerHTML = renderTags(this.topic, {});

    assert
      .dom("a", element)
      .hasText("shared", "the new registry still renders its callback");
  });
});
