import { click, settled, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { AUTO_GROUPS } from "discourse/lib/constants";
import { cloneJSON } from "discourse/lib/object";
import topicFixtures from "discourse/tests/fixtures/topic";
import {
  acceptance,
  publishToMessageBus,
  query,
  selectText,
} from "discourse/tests/helpers/qunit-helpers";
import aiHelperPrompts from "../fixtures/ai-helper-prompts";

acceptance("AI Helper - Post Helper Menu", function (needs) {
  needs.settings({
    discourse_ai_enabled: true,
    ai_helper_enabled: true,
    post_ai_helper_allowed_groups: "1|2",
    ai_helper_enabled_features: "suggestions|context_menu",
    share_quote_visibility: "anonymous",
    enable_markdown_footnotes: true,
    display_footnotes_inline: true,
  });
  needs.user({
    admin: true,
    moderator: true,
    groups: [AUTO_GROUPS.admins],
    can_use_assistant_in_post: true,
    ai_helper_prompts: aiHelperPrompts,
    trust_level: 4,
  });
  needs.pretender((server, helper) => {
    server.get("/t/1.json", () => {
      const json = cloneJSON(topicFixtures["/t/28830/1.json"]);
      json.post_stream.posts[0].can_edit_post = true;
      json.post_stream.posts[0].can_edit = true;
      return helper.response(json);
    });

    server.get("/t/2.json", () => {
      const json = cloneJSON(topicFixtures["/t/28830/1.json"]);
      json.post_stream.posts[0].cooked =
        "<p>La lluvia en España se queda principalmente en el avión.</p>";
      return helper.response(json);
    });

    server.post(`/discourse-ai/ai-helper/stream_suggestion/`, () => {
      return helper.response({
        result: "This is a suggestio",
        done: false,
        progress_channel: "/some/progress/channel",
      });
    });

    server.get("/discourse-ai/ai-bot/conversations.json", () => {});
  });

  test("displays streamed explanation", async function (assert) {
    await visit("/t/-/1");
    const suggestion = "This is a suggestion that is completed";
    const textNode = query("#post_1 .cooked p").childNodes[0];
    await selectText(textNode, 9);
    await click(".ai-post-helper__trigger");
    await click(".ai-helper-options__button[data-name='explain']");
    await publishToMessageBus(`/some/progress/channel`, {
      done: true,
      result: suggestion,
    });
    assert.dom(".ai-post-helper__suggestion__text").hasText(suggestion);
  });

  async function selectSpecificText(textNode, start, end) {
    const range = document.createRange();
    range.setStart(textNode, start);
    range.setEnd(textNode, end);
    const selection = window.getSelection();
    selection.removeAllRanges();
    selection.addRange(range);
    const event = new PointerEvent("pointerup");
    document.dispatchEvent(event);
    await settled();
  }

  test("adds explained text as footnote to post", async function (assert) {
    await visit("/t/-/1");
    const suggestion = "This is a suggestion that is completed";

    const textNode = query("#post_1 .cooked p").childNodes[0];
    await selectSpecificText(textNode, 72, 77);
    await click(".ai-post-helper__trigger");
    await click(".ai-helper-options__button[data-name='explain']");
    await publishToMessageBus(`/some/progress/channel`, {
      done: true,
      result: suggestion,
    });

    assert.dom(".ai-post-helper__suggestion__insert-footnote").isDisabled();
  });

  test("shows translated post", async function (assert) {
    await visit("/t/-/2");
    const translated = "The rain in Spain, stays mainly in the Plane.";
    await selectText(query("#post_1 .cooked p"));
    await click(".ai-post-helper__trigger");
    await click(".ai-helper-options__button[data-name='translate']");
    await publishToMessageBus(`/some/progress/channel`, {
      done: true,
      result: translated,
    });
    assert.dom(".ai-post-helper__suggestion__text").hasText(translated);
  });
});
