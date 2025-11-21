import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { cloneJSON } from "discourse/lib/object";
import postFixtures from "discourse/tests/fixtures/post";
import topicFixtures from "discourse/tests/fixtures/topic";
import {
  acceptance,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { i18n } from "discourse-i18n";

acceptance("Discourse Policy - post", function (needs) {
  needs.user();

  needs.settings({
    policy_enabled: true,
  });

  needs.pretender((server, helper) => {
    const topic = cloneJSON(topicFixtures["/t/130.json"]);
    const post = cloneJSON(postFixtures["/posts/18"]);

    post.topic_id = topic.id;
    post.policy_can_accept = true;
    post.cooked = `<div class=\"policy\" data-group=\"everyone\" data-version=\"1\">\n<p>test</p>\n</div>`;

    topic.post_stream = {
      posts: [post],
      stream: [post.id],
    };

    server.get("/t/130.json", () => helper.response(topic));
    server.put("/policy/accept", () => helper.response(200, {}));
    server.put("/policy/unaccept", () => helper.response(200, {}));
  });

  test("insert a policy", async function (assert) {
    updateCurrentUser({ can_create_policy: true });
    await visit("/t/-/130");
    await click(".actions .edit");

    await fillIn("textarea.d-editor-input", "");

    await click(".toolbar-menu__options-trigger");
    await click(`button[title="${i18n("discourse_policy.builder.attach")}"]`);
    await selectKit(".group-chooser").expand();
    await selectKit(".group-chooser").fillInFilter("staff");
    await selectKit(".group-chooser").selectRowByValue("staff");
    await selectKit(".group-chooser").collapse();

    await selectKit(".combo-box").expand();
    await selectKit(".combo-box").selectRowByIndex(0);

    await click(".d-modal__footer .btn-primary");

    let raw = document.querySelector("textarea.d-editor-input").value;

    assert.strictEqual(
      raw.trim(),
      '[policy reminder="daily" version="1" groups="staff"]\nI accept this policy\n[/policy]'
    );
  });

  test("edit email preferences", async function (assert) {
    await visit(`/u/eviltrout/preferences/emails`);
    assert.dom("#user_policy_email_frequency").exists();
  });

  test("edit policy - staff", async function (assert) {
    await visit("/t/-/130");
    await click(".edit-policy-settings-btn");

    assert.dom(".policy-builder").exists();
    await selectKit(".group-chooser").expand();
    await selectKit(".group-chooser").selectRowByName("admins");
    await selectKit(".group-chooser").selectRowByName("moderators");
    await selectKit(".group-chooser").collapse();

    await assert.strictEqual(
      selectKit(".group-chooser").header().value(),
      "admins,moderators"
    );
  });

  test("edit policy - not staff", async function (assert) {
    updateCurrentUser({ moderator: false, admin: false });
    await visit("/t/-/130");

    assert.dom(".edit-policy-settings-btn").doesNotExist();
  });

  test("edit policy - not staff, post owner", async function (assert) {
    updateCurrentUser({ moderator: false, admin: false, id: 1 });
    await visit("/t/-/130");

    assert.dom(".edit-policy-settings-btn").exists();
  });

  test("accept a policy", async function (assert) {
    await visit("/t/-/130");
    await click(".btn-accept-policy");

    assert.dom(".btn-revoke-policy").exists();
  });

  test("revoke a policy", async function (assert) {
    await visit("/t/-/130");
    await click(".btn-accept-policy");
    await click(".btn-revoke-policy");

    assert.dom(".btn-accept-policy").exists();
  });
});
