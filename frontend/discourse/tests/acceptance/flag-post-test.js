import { click, fillIn, triggerEvent, visit } from "@ember/test-helpers";
import { test } from "qunit";
import userFixtures from "discourse/tests/fixtures/user-fixtures";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";

async function openFlagModal() {
  if (
    document.querySelector(
      ".topic-post[data-post-number='1'] button.show-more-actions"
    )
  ) {
    await click(".topic-post[data-post-number='1'] button.show-more-actions");
  }
  await click(".topic-post[data-post-number='1'] button.create-flag");
}

async function pressEnter(selector, modifier) {
  await triggerEvent(selector, "keydown", {
    bubbles: true,
    cancelable: true,
    key: "Enter",
    keyCode: 13,
    [modifier]: true,
  });
}

["enabled", "disabled"].forEach((postStreamMode) => {
  acceptance(
    `flagging (glimmer_post_stream_mode = ${postStreamMode})`,
    function (needs) {
      needs.settings({
        glimmer_post_stream_mode: postStreamMode,
      });
      needs.user({ admin: true });
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
            can_be_deleted: true,
            can_delete_all_posts: true,
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
            silence: {
              silence_reason: "spamming",
              silenced_at: "",
              silenced_till: "",
              silenced_by: "",
            },
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
        assert.dom(".flag-modal-body").exists("shows the flag modal");
      });

      test("Flag take action dropdown exists", async function (assert) {
        await visit("/t/internationalization-localization/280");
        await openFlagModal();
        await click("#radio_inappropriate");
        await selectKit(".reviewable-action-dropdown").expand();
        assert
          .dom("[data-value='agree_and_silence']")
          .exists("it shows the silence action option");
        assert
          .dom("[data-value='agree_and_suspend']")
          .exists("it shows the suspend action option");
        assert
          .dom("[data-value='agree_and_hide']")
          .exists("it shows the hide action option");
      });

      test("Can silence from take action", async function (assert) {
        await visit("/t/internationalization-localization/280");
        await openFlagModal();
        await click("#radio_inappropriate");
        await selectKit(".reviewable-action-dropdown").expand();
        await click("[data-value='agree_and_silence']");
        assert.dom(".silence-user-modal").exists("shows the silence modal");
        assert.dom(".suspend-message").hasValue("", "penalty message is empty");
        const silenceUntilCombobox = selectKit(".silence-until .combobox");
        await silenceUntilCombobox.expand();
        await silenceUntilCombobox.selectRowByValue("tomorrow");
        assert.dom(".d-modal__body").exists();
        await fillIn("input.silence-reason", "for breaking the rules");

        await click(".perform-penalize");
        assert.dom(".d-modal__body").doesNotExist();
      });

      test("Message appears in penalty modal", async function (assert) {
        this.siteSettings.penalty_include_post_message = true;
        await visit("/t/internationalization-localization/280");
        await openFlagModal();
        await click("#radio_inappropriate");
        await selectKit(".reviewable-action-dropdown").expand();
        await click("[data-value='agree_and_silence']");
        assert.dom(".silence-user-modal").exists("shows the silence modal");
        assert
          .dom(".suspend-message")
          .hasValue(
            "-------------------\n<p>Any plans to support localization of UI elements, so that I (for example) could set up a completely German speaking forum?</p>\n-------------------",
            "penalty message is prefilled with post text"
          );
      });

      test("Can delete spammer from spam", async function (assert) {
        await visit("/t/internationalization-localization/280");
        await openFlagModal();
        await click("#radio_spam");

        assert.dom(".delete-spammer").exists();
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
        await fillIn("input.silence-reason", "for breaking the rules");
        await click(".d-modal-cancel");
        assert.dom(".dialog-body").exists();

        await click(".dialog-footer .btn-default");
        assert.dom(".dialog-body").doesNotExist();
        assert.dom(".silence-user-modal").exists("shows the silence modal");

        await click(".d-modal-cancel");
        assert.dom(".dialog-body").exists();

        await click(".dialog-footer .btn-primary");
        assert.dom(".dialog-body").doesNotExist();
      });

      test("CTRL + ENTER accepts the modal", async function (assert) {
        await visit("/t/internationalization-localization/280");
        await openFlagModal();

        await pressEnter(".d-modal", "ctrlKey");
        assert
          .dom(".d-modal")
          .exists(
            "The modal wasn't closed because the accept button was disabled"
          );

        await click("#radio_inappropriate"); // this enables the accept button
        await pressEnter(".d-modal", "ctrlKey");
        assert.dom(".d-modal").doesNotExist("The modal was closed");
      });

      test("CMD or WINDOWS-KEY + ENTER accepts the modal", async function (assert) {
        await visit("/t/internationalization-localization/280");
        await openFlagModal();

        await pressEnter(".d-modal", "metaKey");
        assert
          .dom(".d-modal")
          .exists(
            "The modal wasn't closed because the accept button was disabled"
          );

        await click("#radio_inappropriate"); // this enables the accept button
        await pressEnter(".d-modal", "ctrlKey");
        assert.dom(".d-modal").doesNotExist("The modal was closed");
      });
    }
  );
});
