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
import { i18n } from "discourse-i18n";
import selectKit from "../helpers/select-kit-helper";

acceptance("Personal Message", function (needs) {
  needs.user({ id: 1 });

  test("suggested messages", async function (assert) {
    await visit("/t/pm-for-testing/12");

    assert
      .dom("#suggested-topics-title")
      .hasText(i18n("suggested_topics.pm_title"));
  });

  test("redirects to inbox after topic is archived and clears topicList cache", async function (assert) {
    const session = getOwner(this).lookup("service:session");
    setCachedTopicList(session, {});

    await visit("/t/pm-for-testing/12");
    await click(".archive-topic");

    assert.strictEqual(currentURL(), "/u/eviltrout/messages");
    assert.strictEqual(
      getCachedTopicList(session),
      undefined,
      "topic list cached is cleared"
    );
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
    await click(".topic-map__private-message-map .add-participant-btn");

    assert
      .dom(".d-modal.add-pm-participants .invite-user-control")
      .exists("invite modal is displayed");
  });

  test("shows errors correctly", async function (assert) {
    await visit("/t/pm-for-testing/12");
    await click(".topic-map__private-message-map .add-participant-btn");

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

acceptance("Personal Message - email invite", function (needs) {
  needs.user({ admin: true });
  needs.pretender((server, helper) => {
    server.get("/u/search/users", () => helper.response({ users: [] }));
    server.post("/t/12/invite", () => helper.response({ success: "OK" }));
  });

  test("closes the modal after a generic email success response", async function (assert) {
    await visit("/t/pm-for-testing/12");
    getOwner(this)
      .lookup("controller:topic")
      .model.set("details.can_invite_via_email", true);
    await click(".topic-map__private-message-map .add-participant-btn");

    const input = selectKit(".invite-user-input");
    await input.expand();
    await input.fillInFilter("existing@example.com");
    await input.selectRowByValue("existing@example.com");
    await click(".send-invite");

    assert
      .dom(".d-modal.add-pm-participants")
      .doesNotExist("the invite modal closes instead of showing an empty body");
  });
});

acceptance("Personal Message - recipient updates", function (needs) {
  needs.user();
  needs.pretender((server, helper) => {
    const user = {
      id: 123,
      username: "example",
      name: "Example",
      avatar_template: "/letter_avatar_proxy/v4/letter/e/999999/{size}.png",
    };
    server.get("/u/search/users", () => helper.response({ users: [user] }));
    server.post("/t/12/invite", () => helper.response({ user }));
    server.put("/t/12/remove-allowed-user", () =>
      helper.response({ success: "OK" })
    );
  });

  async function inviteExample() {
    await click(".topic-map__private-message-map .add-participant-btn");
    const input = selectKit(".invite-user-input");
    await input.expand();
    await input.fillInFilter("example");
    await input.selectRowByValue("example");
    await click(".send-invite");
  }

  const recipient =
    '.topic-map__private-message-map [data-user-card="example"]';
  const existingRecipient =
    '.topic-map__private-message-map [data-user-card="someguy"]';
  const retainedRecipient =
    '.topic-map__private-message-map [data-user-card="test"]';

  test("inviting a user updates the recipient list without reloading", async function (assert) {
    await visit("/t/pm-for-testing/12");

    assert.dom(recipient).doesNotExist("the invitee is not yet a recipient");
    assert.dom(existingRecipient).exists("the existing recipient is present");
    assert.dom(retainedRecipient).exists("the other recipient is present");

    await inviteExample();

    assert
      .dom(".d-modal.add-pm-participants")
      .doesNotExist("the invitation succeeds");
    assert
      .dom(recipient)
      .exists("the invited user appears immediately in the recipient list");
    assert.dom(existingRecipient).exists("the existing recipient is retained");
    assert.dom(retainedRecipient).exists("the other recipient is retained");
  });

  test("inviting a user updates the recipient list after removing a recipient", async function (assert) {
    await visit("/t/pm-for-testing/12");

    assert.dom(existingRecipient).exists("the recipient is initially present");
    await click(
      '.topic-map__private-message-map [data-id="2"] .remove-invited'
    );
    assert
      .dom(existingRecipient)
      .doesNotExist("the previous recipient is removed");
    assert.dom(recipient).doesNotExist("the invitee is not yet a recipient");

    await inviteExample();

    assert
      .dom(".d-modal.add-pm-participants")
      .doesNotExist("the invitation succeeds");
    assert
      .dom(recipient)
      .exists("the invited user appears immediately in the recipient list");
    assert
      .dom(existingRecipient)
      .doesNotExist("the removed recipient stays removed");
    assert.dom(retainedRecipient).exists("the remaining recipient is retained");
  });
});
