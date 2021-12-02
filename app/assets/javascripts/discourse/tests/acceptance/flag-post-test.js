import {
  acceptance,
  count,
  exists,
  query,
} from "discourse/tests/helpers/qunit-helpers";
import { click, fillIn, visit } from "@ember/test-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { test } from "qunit";
import userFixtures from "discourse/tests/fixtures/user-fixtures";
import { run } from "@ember/runloop";

async function openFlagModal() {
  if (exists(".topic-post:first-child button.show-more-actions")) {
    await click(".topic-post:first-child button.show-more-actions");
  }
  await click(".topic-post:first-child button.create-flag");
}

function pressEnter(element, modifier) {
  const event = document.createEvent("Event");
  event.initEvent("keydown", true, true);
  event.key = "Enter";
  event.keyCode = 13;
  event[modifier] = true;
  run(() => element.dispatchEvent(event));
}

acceptance("flagging", function (needs) {
  needs.user();
  needs.pretender((server, helper) => {
    server.get("/u/uwe_keim.json", () => {
      return helper.response(userFixtures["/u/charlie.json"]);
    });
    server.get("/admin/users/255.json", () => {
      return helper.response({
        id: 255,
        automatic: false,
        name: "admin",
        username: "admin",
        user_count: 0,
        alias_level: 99,
        visible: true,
        automatic_membership_email_domains: "",
        primary_group: false,
        title: null,
        grant_trust_level: null,
        has_messages: false,
        flair_url: null,
        flair_bg_color: null,
        flair_color: null,
        bio_raw: null,
        bio_cooked: null,
        public_admission: false,
        allow_membership_requests: true,
        membership_request_template: "Please add me",
        full_name: null,
      });
    });
    server.get("/admin/users/5.json", () => {
      return helper.response({
        id: 5,
        automatic: false,
        name: "user",
        username: "user",
        user_count: 0,
        alias_level: 99,
        visible: true,
        automatic_membership_email_domains: "",
        primary_group: false,
        title: null,
        grant_trust_level: null,
        has_messages: false,
        flair_url: null,
        flair_bg_color: null,
        flair_color: null,
        bio_raw: null,
        bio_cooked: null,
        public_admission: false,
        allow_membership_requests: true,
        membership_request_template: "Please add me",
        full_name: null,
      });
    });
    server.put("/admin/users/5/silence", () => {
      return helper.response({
        silenced: true,
      });
    });
    server.post("/post_actions", () => {
      return helper.response({
        response: true,
      });
    });
  });

  test("Flag modal opening", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await openFlagModal();
    assert.ok(exists(".flag-modal-body"), "it shows the flag modal");
  });

  test("Flag take action dropdown exists", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await openFlagModal();
    await click("#radio_inappropriate");
    await selectKit(".reviewable-action-dropdown").expand();
    assert.ok(
      exists("[data-value='agree_and_silence']"),
      "it shows the silence action option"
    );
    await click("[data-value='agree_and_silence']");
    assert.ok(exists(".silence-user-modal"), "it shows the silence modal");
  });

  test("Can silence from take action", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await openFlagModal();
    await click("#radio_inappropriate");
    await selectKit(".reviewable-action-dropdown").expand();
    await click("[data-value='agree_and_silence']");

    const silenceUntilCombobox = selectKit(".silence-until .combobox");
    await silenceUntilCombobox.expand();
    await silenceUntilCombobox.selectRowByValue("tomorrow");
    await fillIn(".silence-reason", "for breaking the rules");
    await click(".perform-silence");
    assert.ok(!exists(".bootbox.modal:visible"));
  });

  test("Gets dismissable warning from canceling incomplete silence from take action", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await openFlagModal();
    await click("#radio_inappropriate");
    await selectKit(".reviewable-action-dropdown").expand();
    await click("[data-value='agree_and_silence']");

    const silenceUntilCombobox = selectKit(".silence-until .combobox");
    await silenceUntilCombobox.expand();
    await silenceUntilCombobox.selectRowByValue("tomorrow");
    await fillIn(".silence-reason", "for breaking the rules");
    await click(".d-modal-cancel");
    assert.strictEqual(count(".bootbox.modal:visible"), 1);

    await click(".modal-footer .btn-default");
    assert.ok(!exists(".bootbox.modal:visible"));
    assert.ok(exists(".silence-user-modal"), "it shows the silence modal");

    await click(".d-modal-cancel");
    assert.strictEqual(count(".bootbox.modal:visible"), 1);

    await click(".modal-footer .btn-primary");
    assert.ok(!exists(".bootbox.modal:visible"));
  });

  test("CTRL + ENTER accepts the modal", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await openFlagModal();

    const modal = query("#discourse-modal");
    pressEnter(modal, "ctrlKey");
    assert.ok(
      exists("#discourse-modal:visible"),
      "The modal wasn't closed because the accept button was disabled"
    );

    await click("#radio_inappropriate"); // this enables the accept button
    pressEnter(modal, "ctrlKey");
    assert.ok(!exists("#discourse-modal:visible"), "The modal was closed");
  });

  test("CMD or WINDOWS-KEY + ENTER accepts the modal", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await openFlagModal();

    const modal = query("#discourse-modal");
    pressEnter(modal, "metaKey");
    assert.ok(
      exists("#discourse-modal:visible"),
      "The modal wasn't closed because the accept button was disabled"
    );

    await click("#radio_inappropriate"); // this enables the accept button
    pressEnter(modal, "ctrlKey");
    assert.ok(!exists("#discourse-modal:visible"), "The modal was closed");
  });
});
