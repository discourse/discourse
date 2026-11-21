import { click, triggerEvent, visit } from "@ember/test-helpers";
import { test } from "qunit";
import sinon from "sinon";
import { cloneJSON } from "discourse/lib/object";
import DiscourseURL from "discourse/lib/url";
import topicFixtures from "discourse/tests/fixtures/topic";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

for (const mobile of [false, true]) {
  acceptance(
    `Topic summary navigation - ${mobile ? "mobile" : "desktop"}`,
    function (needs) {
      needs.user();
      if (mobile) {
        needs.mobileView();
      }
      needs.pretender((server, helper) => {
        const topicResponse = (request) => {
          const json = cloneJSON(topicFixtures["/t/130.json"]);
          json.id = 1;
          json.summarizable = true;
          json.has_cached_summary = true;
          json.has_summary = true;
          json.highest_post_number = 3;
          json.posts_count = 3;
          const firstPost = json.post_stream.posts[0];
          json.post_stream.posts = [1, 2, 3].map((number) => ({
            ...cloneJSON(firstPost),
            id: 132 + number,
            post_number: number,
            topic_id: 1,
          }));
          json.post_stream.stream = [133, 134, 135];
          if (request.queryParams.filter === "summary") {
            json.post_stream.posts = json.post_stream.posts.slice(0, 1);
            json.post_stream.stream = [133];
          }
          return helper.response(json);
        };
        server.get("/discourse-ai/credits/status", () =>
          helper.response({ topic_summaries: { hard_limit_reached: false } })
        );
        server.get("/discourse-ai/ai-bot/conversations.json", () => {});
        server.get("/t/1.json", topicResponse);
        server.get("/t/1/3.json", topicResponse);
        server.get("/discourse-ai/summarization/t/1", () =>
          helper.response({
            ai_topic_summary: {
              summarized_text: "See <a href='/t/-/1/3'>this reply</a>.",
              summarized_on: "2023-01-01T04:00:00.000Z",
              algorithm: "OpenAI GPT-4",
            },
          })
        );
      });

      for (const filtered of [false, true]) {
        test(`follow a reply link${filtered ? " hidden by top replies" : ""}`, async function (assert) {
          await visit("/t/-/1");
          if (filtered) {
            await click(".top-replies");
            assert.dom("#post_3").doesNotExist();
          }
          await click(".ai-summarization-button");
          await triggerEvent(".generated-summary a", "click", {
            ctrlKey: true,
          });
          assert
            .dom(".ai-summary-modal")
            .exists("modified clicks keep the summary open");
          await click(".generated-summary p");
          assert
            .dom(".ai-summary-modal")
            .exists("non-link clicks keep the summary open");

          const jump = sinon.spy(DiscourseURL, "jumpToPost");
          await click(".generated-summary a");
          if (mobile) {
            assert
              .dom(".ai-summary-modal")
              .doesNotExist("closes the mobile summary");
          } else {
            assert
              .dom(".ai-summary-modal")
              .exists("keeps the desktop summary open");
          }
          assert.true(jump.calledWith(3), "jumps to the linked reply");
          assert.dom("#post_3").exists("loads the linked reply");
          assert.false(
            this.container.lookup("controller:topic").model.postStream.summary,
            "clears the top replies filter"
          );
        });
      }
    }
  );
}
