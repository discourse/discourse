import { getOwner } from "@ember/owner";
import { click, currentURL, visit } from "@ember/test-helpers";
import { test } from "qunit";
import sinon from "sinon";
import {
  getCachedTopicList,
  setCachedTopicList,
} from "discourse/lib/cached-topic-list";
import DiscourseURL from "discourse/lib/url";
import {
  acceptance,
  publishToMessageBus,
} from "discourse/tests/helpers/qunit-helpers";
import I18n from "discourse-i18n";
import selectKit from "../helpers/select-kit-helper";

acceptance("Personal Message", function (needs) {
  needs.user({ id: 1 });

  test("suggested messages", async function (assert) {
    await visit("/t/pm-for-testing/12");

    assert
      .dom("#suggested-topics-title")
      .hasText(I18n.t("suggested_topics.pm_title"));
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
  needs.pretender((server, helper) => {
    server.get("/u/search/users", () =>
      helper.response({ users: [{ username: "example" }] })
    );

    server.post("/t/12/invite", () =>
      helper.response(422, {
        errors: ["Some validation error"],
      })
    );
  });

  test("can open invite modal", async function (assert) {
    await visit("/t/pm-for-testing/12");
    await click(".add-remove-participant-btn");
    await click(
      ".topic-map__private-message-map .controls .add-participant-btn"
    );

    assert
      .dom(".d-modal.add-pm-participants .invite-user-control")
      .exists("invite modal is displayed");
  });

  test("shows errors correctly", async function (assert) {
    await visit("/t/pm-for-testing/12");
    await click(".add-remove-participant-btn");
    await click(
      ".topic-map__private-message-map .controls .add-participant-btn"
    );

    assert
      .dom(".d-modal.add-pm-participants .invite-user-control")
      .exists("invite modal is displayed");

    const input = selectKit(".invite-user-input");
    await input.expand();
    await input.fillInFilter("example");
    await input.selectRowByValue("example");

    await click(".send-invite");

    assert.dom(".d-modal.add-pm-participants .alert-error").exists();
  });
});
