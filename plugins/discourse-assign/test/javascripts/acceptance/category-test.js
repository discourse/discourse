import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import DiscoveryFixtures from "discourse/tests/fixtures/discovery-fixtures";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

function stubCategory(needs, customFields) {
  needs.site({
    categories: [
      {
        id: 6,
        name: "test",
        slug: "test",
        custom_fields: customFields,
      },
    ],
  });

  needs.pretender((server, helper) => {
    server.get("/c/test/6/l/latest.json", () => {
      return helper.response(
        DiscoveryFixtures["/latest_can_create_topic.json"]
      );
    });
  });
}

acceptance(
  "Discourse Assign | Categories for users that can assign",
  function (needs) {
    needs.user({ can_assign: true });
    needs.settings({
      assign_enabled: true,
      assigns_user_url_path: "/",
      assigns_public: false,
    });
    stubCategory(needs, { enable_unassigned_filter: "true" });

    test("can see Unassigned button", async function (assert) {
      await visit("/c/test");

      const title = i18n("filters.unassigned.help");
      assert.dom(`#navigation-bar li[title='${title}']`).exists();
    });
  }
);

acceptance(
  "Discourse Assign | Categories without enable_unassigned_filter",
  function (needs) {
    needs.user();
    needs.settings({
      assign_enabled: true,
      assigns_user_url_path: "/",
      assigns_public: false,
    });
    stubCategory(needs, { enable_unassigned_filter: "false" });

    test("cannot see Unassigned button", async function (assert) {
      await visit("/c/test");

      const title = i18n("filters.unassigned.help");
      assert.dom(`#navigation-bar li[title='${title}']`).doesNotExist();
    });
  }
);

acceptance(
  "Discourse Assign | Categories when assigns are public",
  function (needs) {
    needs.user();
    needs.settings({
      assign_enabled: true,
      assigns_user_url_path: "/",
      assigns_public: true,
    });
    stubCategory(needs, { enable_unassigned_filter: "true" });

    test("can see Unassigned button", async function (assert) {
      await visit("/c/test");

      const title = i18n("filters.unassigned.help");
      assert.dom(`#navigation-bar li[title='${title}']`).exists();
    });
  }
);

acceptance(
  "Discourse Assign | Categories when assigns are private",
  function (needs) {
    needs.user();
    needs.settings({
      assign_enabled: true,
      assigns_user_url_path: "/",
      assigns_public: false,
    });
    stubCategory(needs, { enable_unassigned_filter: "true" });

    test("cannot see Unassigned button", async function (assert) {
      await visit("/c/test");

      const title = i18n("filters.unassigned.help");
      assert.dom(`#navigation-bar li[title='${title}']`).doesNotExist();
    });
  }
);
