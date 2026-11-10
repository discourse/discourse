import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import SearchResultEntry from "discourse/components/search-result-entry";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

function buildPost(owner, attrs = {}) {
  const store = owner.lookup("service:store");
  const topic = store.createRecord("topic", { id: 1, title: "A topic" });
  return store.createRecord("post", {
    id: 2,
    topic,
    topic_id: 1,
    created_at: "2026-01-01T00:00:00Z",
    ...attrs,
  });
}

module(
  "Integration | Component | AI search result decoration",
  function (hooks) {
    setupRenderingTest(hooks);

    test("marks AI-generated results", async function (assert) {
      const post = buildPost(this.owner, { generatedByAi: true });

      await render(<template><SearchResultEntry @post={{post}} /></template>);

      assert.dom(".fps-result .ai-result__icon").exists("shows the AI icon");
    });

    test("leaves other results alone", async function (assert) {
      const post = buildPost(this.owner);

      await render(<template><SearchResultEntry @post={{post}} /></template>);

      assert.dom(".ai-result__icon").doesNotExist();
    });
  }
);
