import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import TopicProgress from "discourse/components/topic-progress";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | topic-progress", function (hooks) {
  setupRenderingTest(hooks);

  test("shows the back button on mega topics", async function (assert) {
    const topic = getOwner(this).lookup("service:store").createRecord("topic", {
      id: 1,
      highest_post_number: 100,
      last_read_post_id: 5500,
      last_read_post_number: 80,
    });
    topic.postStream.isMegaTopic = true;

    await render(<template><TopicProgress @topic={{topic}} /></template>);

    assert.dom(".progress-back").exists();
  });
});
