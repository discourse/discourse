import { render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import MobileCategoryTopic from "discourse/components/mobile-category-topic";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | MobileCategoryTopic", function (hooks) {
  setupRenderingTest(hooks);

  test("marks the row as archived and visited", async function (assert) {
    const topic = this.owner.lookup("service:store").createRecord("topic", {
      id: 1,
      title: "A topic",
      highest_post_number: 1,
    });

    await render(
      <template>
        <table><tbody><MobileCategoryTopic @topic={{topic}} /></tbody></table>
      </template>
    );

    assert.dom("tr").hasClass("category-topic-link", "renders a table row");
    assert.dom("tr").doesNotHaveClass("archived");
    assert.dom("tr").doesNotHaveClass("visited");

    topic.set("archived", true);
    topic.set("last_read_post_number", 1);
    await settled();

    assert.dom("tr").hasClass("archived", "follows the topic's archived state");
    assert.dom("tr").hasClass("visited", "follows the topic's visited state");
  });
});
