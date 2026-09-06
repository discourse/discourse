import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import ReviewableChatMessage from "discourse/plugins/chat/discourse/components/reviewable/chat-message";

function reviewable(payload) {
  return {
    type: "ReviewableChatMessage",
    target_id: 1,
    cooked: "<p>flagged message</p>",
    payload,
  };
}

module("Integration | Component | Reviewable | chat-message", function (hooks) {
  setupRenderingTest(hooks);

  test("renders the message uploads captured in the payload", async function (assert) {
    const item = reviewable({
      message_cooked: "<p>look at this</p>",
      message_uploads: [
        {
          id: 1,
          original_filename: "flagged.png",
          extension: "png",
          width: 200,
          height: 100,
          url: "/uploads/default/original/1X/flagged.png",
          short_url: "upload://flagged.png",
          short_path: "/uploads/short-url/flagged.png",
        },
      ],
    });

    await render(
      <template><ReviewableChatMessage @reviewable={{item}} /></template>
    );

    assert
      .dom(".review-item__post-content .chat-uploads img.chat-img-upload")
      .exists("renders the flagged upload as an image");
  });

  test("renders no uploads section when the payload has none", async function (assert) {
    const item = reviewable({ message_cooked: "<p>just text</p>" });

    await render(
      <template><ReviewableChatMessage @reviewable={{item}} /></template>
    );

    assert
      .dom(".review-item__post-content")
      .containsText("just text", "still renders the cooked message");
    assert.dom(".chat-uploads").doesNotExist("renders no uploads section");
  });
});
