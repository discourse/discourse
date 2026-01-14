import EmberObject from "@ember/object";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import renderTags from "discourse/lib/render-tags";

module("Unit | Utility | render-tags", function (hooks) {
  setupTest(hooks);

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
});
