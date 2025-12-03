import EmberObject from "@ember/object";
import Service from "@ember/service";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import AiTopicGist from "discourse/plugins/discourse-ai/discourse/components/ai-topic-gist";
import {
  TABLE_AI_LAYOUT,
  TABLE_LAYOUT,
} from "discourse/plugins/discourse-ai/discourse/services/gists";

module("Integration | Component | ai-topic-gist", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.topic = EmberObject.create({
      ai_topic_gist: "A helpful AI summary",
      escapedExcerpt: "<p>Standard excerpt</p>",
      lastUnreadUrl: "/t/topic/1",
    });
  });

  function registerGistsService(owner, { preference, showToggle = true }) {
    const layoutPreference = preference;
    const toggleVisibility = showToggle;

    owner.unregister?.("service:gists");

    owner.register(
      "service:gists",
      class extends Service {
        constructor(...args) {
          super(...args);
          this.currentPreference = layoutPreference;
          this.showToggle = toggleVisibility;
        }
      }
    );
  }

  test("adds the body class when gists show without the toggle", async function (assert) {
    assert.strictEqual(
      this.topic.get("ai_topic_gist"),
      "A helpful AI summary",
      "topic is accessible in tests"
    );

    registerGistsService(this.owner, {
      preference: TABLE_AI_LAYOUT,
      showToggle: false,
    });

    const gistService = this.owner.lookup("service:gists");
    assert.strictEqual(
      gistService.currentPreference,
      TABLE_AI_LAYOUT,
      "gist service uses the ai layout preference"
    );

    await render(<template><AiTopicGist @topic={{this.topic}} /></template>);

    assert
      .dom(".excerpt__contents")
      .hasText("A helpful AI summary", "gist content is rendered");

    assert.true(
      document.body.classList.contains("topic-list-layout-table-ai"),
      "body class is applied when ai layout is active"
    );
  });

  test("does not add the body class when compact layout is active", async function (assert) {
    registerGistsService(this.owner, {
      preference: TABLE_LAYOUT,
      showToggle: true,
    });

    await render(<template><AiTopicGist @topic={{this.topic}} /></template>);

    assert.false(
      document.body.classList.contains("topic-list-layout-table-ai"),
      "body class is not applied when ai layout is inactive"
    );
  });
});
