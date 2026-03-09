import { getOwner } from "@ember/owner";
import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { withPluginApi } from "discourse/lib/plugin-api";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("post-share-url transformer", function (needs) {
  needs.user();

  test("applying a value transformation", async function (assert) {
    withPluginApi((api) => {
      api.registerValueTransformer("post-share-url", ({ value }) => {
        return "/custom" + value;
      });
    });

    await visit("/t/internationalization-localization/280");

    const topicController = getOwner(this).lookup("controller:topic");
    const post = topicController.model.postStream.posts[0];

    assert.true(
      post.shareUrl.startsWith("/custom"),
      "it transforms the share url"
    );
  });

  test("transformer receives the post in context", async function (assert) {
    let receivedPost;

    withPluginApi((api) => {
      api.registerValueTransformer("post-share-url", ({ value, context }) => {
        receivedPost = context.post;
        return value;
      });
    });

    await visit("/t/internationalization-localization/280");

    const topicController = getOwner(this).lookup("controller:topic");
    const post = topicController.model.postStream.posts[0];
    // access shareUrl to trigger the transformer
    post.shareUrl;

    assert.strictEqual(
      receivedPost.post_number,
      1,
      "transformer receives the correct post in context"
    );
  });
});
