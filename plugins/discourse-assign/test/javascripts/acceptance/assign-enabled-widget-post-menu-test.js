import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { cloneJSON } from "discourse/lib/object";
import userFixtures from "discourse/tests/fixtures/user-fixtures";
import pretender, {
  parsePostData,
  response,
} from "discourse/tests/helpers/create-pretender";
import {
  acceptance,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";

// TODO (glimmer-post-menu): Remove this file when the post menu widget code is removed from core
acceptance(
  "Discourse Assign | Widget Post Menu | Assign mobile",
  function (needs) {
    needs.user();
    needs.mobileView();
    needs.settings({
      glimmer_post_menu_mode: "disabled",
      assign_enabled: true,
    });

    needs.pretender((server, helper) => {
      server.get("/assign/suggestions", () => {
        return helper.response({
          success: true,
          assign_allowed_groups: false,
          assign_allowed_for_groups: [],
          suggestions: [
            {
              id: 19,
              username: "eviltrout",
              name: "Robin Ward",
              avatar_template:
                "/user_avatar/meta.discourse.org/eviltrout/{size}/5275_2.png",
            },
          ],
        });
      });
    });

    test("Footer dropdown contains button", async function (assert) {
      updateCurrentUser({ can_assign: true });
      await visit("/t/internationalization-localization/280");
      await click(".topic-footer-mobile-dropdown-trigger");
      await click(".assign");
      assert.dom(".assign.d-modal").exists("assign modal opens");
    });
  }
);

acceptance(
  "Discourse Assign | Widget Post Menu | Assign desktop",
  function (needs) {
    needs.user({
      can_assign: true,
    });
    needs.settings({
      glimmer_post_menu_mode: "disabled",
      assign_enabled: true,
    });

    needs.pretender((server, helper) => {
      server.get("/assign/suggestions", () => {
        return helper.response({
          success: true,
          assign_allowed_groups: false,
          assign_allowed_for_groups: [],
          suggestions: [
            {
              id: 19,
              username: "eviltrout",
              name: "Robin Ward",
              avatar_template:
                "/user_avatar/meta.discourse.org/eviltrout/{size}/5275_2.png",
            },
          ],
        });
      });
    });

    test("Assigning user to a post", async function (assert) {
      await visit("/t/internationalization-localization/280");

      assert
        .dom("#post_2 .extra-buttons .d-icon-user-plus")
        .doesNotExist("assign to post button is hidden");

      await click("#post_2 button.show-more-actions");
      assert
        .dom("#post_2 .extra-buttons .d-icon-user-plus")
        .exists("assign to post button exists");

      await click("#post_2 .extra-buttons .d-icon-user-plus");
      assert.dom(".assign.d-modal").exists("assign modal opens");

      const menu = selectKit(".assign.d-modal .user-chooser");
      assert.true(menu.isExpanded(), "user selector is expanded");

      await click(".assign.d-modal .btn-primary");
      assert.dom(".error-label").includesText("Choose a user to assign");

      await menu.expand();
      await menu.selectRowByIndex(0);
      assert.strictEqual(menu.header().value(), "eviltrout");
      assert.dom(".error-label").doesNotExist();

      pretender.put("/assign/assign", ({ requestBody }) => {
        const body = parsePostData(requestBody);
        assert.strictEqual(body.target_type, "Post");
        assert.strictEqual(body.username, "eviltrout");
        assert.strictEqual(body.note, "a note!");
        return response({ success: true });
      });

      await fillIn("#assign-modal-note", "a note!");
      await click(".assign.d-modal .btn-primary");

      assert.dom(".assign.d-modal").doesNotExist("assign modal closes");
    });

    test("Footer dropdown contains button", async function (assert) {
      await visit("/t/internationalization-localization/280");
      await click("#topic-footer-button-assign");

      assert.dom(".assign.d-modal").exists("assign modal opens");
    });
  }
);

acceptance(
  "Discourse Assign | Widget Post Menu | Assign Status enabled",
  function (needs) {
    needs.user({
      can_assign: true,
    });
    needs.settings({
      glimmer_post_menu_mode: "disabled",
      assign_enabled: true,
      enable_assign_status: true,
      assign_statuses: "New|In Progress|Done",
    });

    needs.pretender((server, helper) => {
      server.get("/assign/suggestions", () => {
        return helper.response({
          success: true,
          assign_allowed_groups: false,
          assign_allowed_for_groups: [],
          suggestions: [
            {
              id: 19,
              username: "eviltrout",
              name: "Robin Ward",
              avatar_template:
                "/user_avatar/meta.discourse.org/eviltrout/{size}/5275_2.png",
            },
          ],
        });
      });
    });

    test("Modal contains status dropdown", async function (assert) {
      pretender.put("/assign/assign", ({ requestBody }) => {
        const body = parsePostData(requestBody);
        assert.strictEqual(body.target_type, "Topic");
        assert.strictEqual(body.target_id, "280");
        assert.strictEqual(body.username, "eviltrout");
        assert.strictEqual(body.status, "In Progress");

        return response({ success: true });
      });

      await visit("/t/internationalization-localization/280");
      await click("#topic-footer-button-assign");

      assert
        .dom(".assign.d-modal #assign-status")
        .exists("assign status dropdown exists");

      const statusDropdown = selectKit("#assign-status");
      assert.strictEqual(statusDropdown.header().value(), "New");

      await statusDropdown.expand();
      await statusDropdown.selectRowByValue("In Progress");
      assert.strictEqual(statusDropdown.header().value(), "In Progress");

      const menu = selectKit(".assign.d-modal .user-chooser");
      await menu.expand();
      await menu.selectRowByIndex(0);

      await click(".assign.d-modal .btn-primary");
    });
  }
);

acceptance(
  "Discourse Assign | Widget Post Menu | Assign Status disabled",
  function (needs) {
    needs.user({
      can_assign: true,
    });
    needs.settings({
      glimmer_post_menu_mode: "disabled",
      assign_enabled: true,
      enable_assign_status: false,
    });

    needs.pretender((server, helper) => {
      server.get("/assign/suggestions", () => {
        return helper.response({
          success: true,
          assign_allowed_groups: false,
          assign_allowed_for_groups: [],
          suggestions: [
            {
              id: 19,
              username: "eviltrout",
              name: "Robin Ward",
              avatar_template:
                "/user_avatar/meta.discourse.org/eviltrout/{size}/5275_2.png",
            },
          ],
        });
      });
    });

    test("Modal contains status dropdown", async function (assert) {
      await visit("/t/internationalization-localization/280");
      await click("#topic-footer-button-assign");

      assert
        .dom(".assign.d-modal #assign-status")
        .doesNotExist("assign status dropdown doesn't exists");
    });
  }
);

// See RemindAssignsFrequencySiteSettings
const remindersFrequency = [
  {
    name: "discourse_assign.reminders_frequency.never",
    value: 0,
  },
  {
    name: "discourse_assign.reminders_frequency.daily",
    value: 1440,
  },
  {
    name: "discourse_assign.reminders_frequency.weekly",
    value: 10080,
  },
  {
    name: "discourse_assign.reminders_frequency.monthly",
    value: 43200,
  },
  {
    name: "discourse_assign.reminders_frequency.quarterly",
    value: 129600,
  },
];

acceptance(
  "Discourse Assign | Widget Post Menu | User preferences",
  function (needs) {
    needs.user({ can_assign: true, reminders_frequency: remindersFrequency });
    needs.settings({
      glimmer_post_menu_mode: "disabled",
      assign_enabled: true,
      remind_assigns_frequency: 43200,
    });

    test("The frequency for assigned topic reminders defaults to the site setting", async function (assert) {
      await visit("/u/eviltrout/preferences/notifications");

      assert.strictEqual(
        selectKit("#remind-assigns-frequency").header().value(),
        "43200",
        "set frequency to default of Monthly"
      );
    });

    test("The user can change the frequency to Never", async function (assert) {
      await visit("/u/eviltrout/preferences/notifications");

      await selectKit("#remind-assigns-frequency").expand();
      await selectKit("#remind-assigns-frequency").selectRowByValue(0);

      assert.strictEqual(
        selectKit("#remind-assigns-frequency").header().value(),
        "0",
        "set frequency to Never"
      );
    });

    test("The user can change the frequency to some other non-default value", async function (assert) {
      await visit("/u/eviltrout/preferences/notifications");

      await selectKit("#remind-assigns-frequency").expand();
      await selectKit("#remind-assigns-frequency").selectRowByValue(10080); // weekly

      assert.strictEqual(
        selectKit("#remind-assigns-frequency").header().value(),
        "10080",
        "set frequency to Weekly"
      );
    });
  }
);

acceptance(
  "Discourse Assign | Widget Post Menu | User preferences | Pre-selected reminder frequency",
  function (needs) {
    needs.user({ can_assign: true, reminders_frequency: remindersFrequency });
    needs.settings({
      glimmer_post_menu_mode: "disabled",
      assign_enabled: true,
      remind_assigns_frequency: 43200,
    });

    needs.pretender((server, helper) => {
      server.get("/u/eviltrout.json", () => {
        let json = cloneJSON(userFixtures["/u/eviltrout.json"]);
        json.user.custom_fields = { remind_assigns_frequency: 10080 };

        // usually this is done automatically by this pretender but we
        // have to do it manually here because we are overriding the
        // pretender see app/assets/javascripts/discourse/tests/helpers/create-pretender.js
        json.user.can_edit = true;

        return helper.response(200, json);
      });
    });

    test("The user's previously selected value is loaded", async function (assert) {
      await visit("/u/eviltrout/preferences/notifications");

      assert.strictEqual(
        selectKit("#remind-assigns-frequency").header().value(),
        "10080",
        "frequency is pre-selected to Weekly"
      );
    });
  }
);
