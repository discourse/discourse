import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { cloneJSON } from "discourse/lib/object";
import topicFixtures from "discourse/tests/fixtures/topic";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("AI artifact | cooked shared snapshot", function (needs) {
  needs.user();
  needs.settings({
    discourse_ai_enabled: true,
    ai_bot_enabled: true,
    ai_artifact_security: "lax",
  });
  needs.pretender((server, helper) => {
    const topic = cloneJSON(topicFixtures["/t/280/1.json"]);
    topic.post_stream.posts[0].cooked =
      '<blockquote><div class="ai-artifact" data-ai-artifact-share-key="post-key" data-ai-artifact-id="12" data-ai-artifact-version="2" data-ai-artifact-height="640" data-trace="ok"></div></blockquote>';
    server.get("/t/280.json", () => helper.response(topic));
  });

  test("cooked post decoration mounts the native renderer with share key precedence", async function (assert) {
    await visit("/t/internationalization-localization/280");
    assert
      .dom("#post_1 blockquote .ai-artifact iframe")
      .hasAttribute(
        "src",
        "/discourse-ai/ai-bot/artifact-shares/post-key/forum",
        "quoted post uses the native snapshot rather than the artifact version"
      )
      .hasAttribute("data-trace", "ok", "unrelated metadata is preserved")
      .doesNotHaveAttribute(
        "data-ai-artifact-share-key",
        "share key is not generic metadata"
      );
    assert
      .dom("#post_1 .ai-artifact-share")
      .doesNotExist("no eligibility component is mounted");
    assert
      .dom("#post_1 .ai-artifact__wrapper")
      .hasAttribute("style", /height: 640px/);
  });
});
