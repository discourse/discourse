import { exists } from "discourse/tests/helpers/qunit-helpers";
import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import userFixtures from "discourse/tests/fixtures/user-fixtures";

async function openFlagModal() {
  if (exists(".topic-post:first-child button.show-more-actions")) {
    await click(".topic-post:first-child button.show-more-actions");
  }
  await click(".topic-post:first-child button.create-flag");
}

acceptance("flagging", function (needs) {
  needs.user();
  needs.pretender((server, helper) => {
    const userResponse = Object.assign({}, userFixtures["/u/charlie.json"]);
    server.get("/u/uwe_keim.json", () => {
      return helper.response(userResponse);
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
    server.put("admin/users/5/silence", () => {
      return helper.response({
        silenced: true,
      });
    });
    server.post("post_actions", () => {
      return helper.response({
        response: true,
      });
    });
  });

  test("Flag modal opening", async (assert) => {
    await visit("/t/internationalization-localization/280");
    await openFlagModal();
    assert.ok(exists(".flag-modal-body"), "it shows the flag modal");
  });

  test("Flag take action dropdown exists", async (assert) => {
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

  test("Can silence from take action", async (assert) => {
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
    assert.equal(find(".bootbox.modal:visible").length, 0);
  });

  test("Gets dismissable warning from canceling incomplete silence from take action", async (assert) => {
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
    assert.equal(find(".bootbox.modal:visible").length, 1);

    await click(".modal-footer .btn-default");
    assert.equal(find(".bootbox.modal:visible").length, 0);
    assert.ok(exists(".silence-user-modal"), "it shows the silence modal");

    await click(".d-modal-cancel");
    assert.equal(find(".bootbox.modal:visible").length, 1);

    await click(".modal-footer .btn-primary");
    assert.equal(find(".bootbox.modal:visible").length, 0);
  });
});
