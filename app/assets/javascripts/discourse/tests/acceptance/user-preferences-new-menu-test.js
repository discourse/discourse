import { acceptance, exists } from "discourse/tests/helpers/qunit-helpers";
import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import selectKit from "discourse/tests/helpers/select-kit-helper";

acceptance(
  "New User Menu - Horizontal nav and preferences relocation",
  function (needs) {
    needs.user({
      redesigned_user_page_nav_enabled: true,
      user_api_keys: [
        {
          id: 1,
          application_name: "Discourse Hub",
          scopes: ["Read and clear notifications"],
          created_at: "2020-11-14T00:57:09.093Z",
          last_used_at: "2022-09-22T18:55:41.672Z",
        },
      ],
    });

    test("Horizontal user nav exists", async function (assert) {
      await visit("/u/eviltrout/preferences");
      assert.ok(exists(".horizontal-overflow-nav"), "horizontal nav exists");
    });

    test("User Tracking page exists", async function (assert) {
      await visit("/u/eviltrout/preferences");
      assert.ok(exists(".nav-tracking"), "the new tracking page link exists");
    });

    test("User Categories page no longer exists", async function (assert) {
      await visit("/u/eviltrout/preferences");
      assert.ok(!exists(".nav-categories"), "Categories tab no longer exists");
    });

    test("Can save category tracking preferences", async function (assert) {
      await visit("/u/eviltrout/preferences/tracking");

      const categorySelector = selectKit(
        ".tracking-controls .category-selector"
      );

      const savePreferences = async () => {
        assert.notOk(exists(".saved"), "it hasn't been saved yet");
        await click(".save-changes");
        assert.ok(exists(".saved"), "it displays the saved message");
      };

      await categorySelector.expand();
      await categorySelector.fillInFilter("faq");
      await savePreferences();
    });

    test("Can view user api keys on security page", async function (assert) {
      await visit("/u/eviltrout/preferences/security");
      assert.ok(exists(".control-group.apps"), "User can see apps section");
    });
  }
);
