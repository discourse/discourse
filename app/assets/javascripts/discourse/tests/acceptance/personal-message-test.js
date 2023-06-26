import { click, currentURL, visit } from "@ember/test-helpers";
import DiscourseURL from "discourse/lib/url";
import {
  acceptance,
  publishToMessageBus,
  query,
} from "discourse/tests/helpers/qunit-helpers";
import I18n from "I18n";
import { test } from "qunit";
import sinon from "sinon";
import {
  getCachedTopicList,
  setCachedTopicList,
} from "discourse/lib/cached-topic-list";
import { getOwner } from "discourse-common/lib/get-owner";

acceptance("Personal Message", function (needs) {
  needs.user();

  test("suggested messages", async function (assert) {
    await visit("/t/pm-for-testing/12");

    assert.strictEqual(
      query("#suggested-topics .suggested-topics-title").innerText.trim(),
      I18n.t("suggested_topics.pm_title")
    );
  });

  test("redirects to inbox after topic is archived and clears topicList cache", async function (assert) {
    const session = getOwner(this).lookup("service:session");
    setCachedTopicList(session, {});

    await visit("/t/pm-for-testing/12");
    await click(".archive-topic");

    assert.strictEqual(currentURL(), "/u/eviltrout/messages");
    assert.notOk(getCachedTopicList(session), "topic list cached is cleared");
  });
});

acceptance("Personal Message (regular user)", function (needs) {
  needs.user({ admin: false, moderator: false });

  needs.pretender((server) => {
    server.get("/posts/15", () => [
      403,
      {},
      {
        errors: ["You are not permitted to view the requested resource."],
        error_type: "invalid_access",
      },
    ]);
  });

  test("redirects to homepage after topic is deleted", async function (assert) {
    sinon.stub(DiscourseURL, "redirectTo");

    await visit("/t/pm-for-testing/12");

    await click(".post-controls .show-more-actions");
    await click(".post-controls .delete");
    await publishToMessageBus("/topic/12", {
      id: 15,
      post_number: 1,
      updated_at: "2017-01-27T03:53:58.394Z",
      user_id: 8,
      last_editor_id: 8,
      type: "deleted",
      version: 1,
    });

    assert.true(DiscourseURL.redirectTo.calledWith("/"));
  });
});

acceptance("Personal Message - invite", function (needs) {
  needs.user();

  test("suggested messages", async function (assert) {
    await visit("/t/pm-for-testing/12");
    await click(".add-remove-participant-btn");
    await click(".private-message-map .controls .add-participant-btn");

    assert
      .dom(".d-modal.share-and-invite .invite-user-control")
      .exists("invite modal is displayed");
  });
});
