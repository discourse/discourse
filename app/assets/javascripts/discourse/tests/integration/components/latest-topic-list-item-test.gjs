import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import LatestTopicListItem from "discourse/components/topic-list/latest-topic-list-item";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | latest-topic-list-item", function (hooks) {
  setupRenderingTest(hooks);

  test("latest-topic-list-item-class value transformer", async function (assert) {
    withPluginApi("1.39.0", (api) => {
      api.registerValueTransformer(
        "latest-topic-list-item-class",
        ({ value, context }) => {
          if (context.topic.get("foo")) {
            value.push("bar");
          }
          return value;
        }
      );
    });

    const store = this.owner.lookup("service:store");
    const topic = store.createRecord("topic", { id: 1234, foo: true });
    const topic2 = store.createRecord("topic", { id: 1235, foo: false });
    await render(<template>
      <LatestTopicListItem @topic={{topic}} />
      <LatestTopicListItem @topic={{topic2}} />
    </template>);

    assert.dom(".latest-topic-list-item[data-topic-id='1234']").hasClass("bar");
    assert
      .dom(".latest-topic-list-item[data-topic-id='1235']")
      .doesNotHaveClass("bar");
  });
});
