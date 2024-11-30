import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | pending-post", function (hooks) {
  setupRenderingTest(hooks);

  test("it renders", async function (assert) {
    const store = getOwner(this).lookup("service:store");
    store.createRecord("category", { id: 2 });
    const post = store.createRecord("pending-post", {
      id: 1,
      topic_url: "topic-url",
      username: "USERNAME",
      category_id: 2,
      raw_text: "**bold text**",
    });
    this.set("post", post);

    await render(hbs`<PendingPost @post={{this.post}}/>`);

    assert.dom("p.excerpt").hasText("bold text", "renders the cooked text");
  });
});
