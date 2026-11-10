import EmberObject from "@ember/object";
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
