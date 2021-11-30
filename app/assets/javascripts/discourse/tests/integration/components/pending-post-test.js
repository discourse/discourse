import { module, test } from "qunit";
import { setupRenderingTest } from "ember-qunit";
import { render } from "@ember/test-helpers";
import hbs from "htmlbars-inline-precompile";
import PendingPost from "discourse/models/pending-post";
import createStore from "discourse/tests/helpers/create-store";

const LEGACY_ENV = !setupRenderingTest;

module("Integration | Component | pending-post", function (hooks) {
  if (LEGACY_ENV) {
    return;
  }

  setupRenderingTest(hooks);

  test("it renders", async function (assert) {
    const store = createStore();
    store.createRecord("category", { id: 2 });
    const post = PendingPost.create({
      id: 1,
      topic_url: "topic-url",
      username: "USERNAME",
      category_id: 2,
      raw_text: "**bold text**",
    });
    this.set("post", post);

    await render(hbs`<PendingPost @post={{this.post}}/>`);

    assert.equal(
      this.element.querySelector("p.excerpt").textContent.trim(),
      "bold text",
      "renders the cooked text"
    );
  });
});
