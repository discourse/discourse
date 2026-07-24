import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import DiscoveryFixtures from "discourse/tests/fixtures/discovery-fixtures";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance(
  "Create Topic button visibility - hide_disabled_create_topic_button",
  function (needs) {
    needs.user();
    needs.pretender((server, helper) => {
      server.get("/c/writable-category/7/l/latest.json", () => {
        return helper.response(
          DiscoveryFixtures["/latest_can_create_topic.json"]
        );
      });
      server.get("/c/read-only-category/8/l/latest.json", () => {
        return helper.response(
          DiscoveryFixtures["/latest_can_create_topic.json"]
        );
      });
    });
    needs.site({
      categories: [
        {
          id: 7,
          name: "writable category",
          slug: "writable-category",
          permission: 1,
        },
        {
          id: 8,
          name: "read only category",
          slug: "read-only-category",
          permission: null,
        },
      ],
    });

    test("shows the button on writable categories when setting is enabled", async function (assert) {
      this.siteSettings.hide_disabled_create_topic_button = true;

      await visit("/c/writable-category");

      assert.dom("#create-topic").exists();
    });

    test("hides the button on read-only categories when setting is enabled", async function (assert) {
      this.siteSettings.hide_disabled_create_topic_button = true;

      await visit("/c/read-only-category");

      assert.dom("#create-topic").doesNotExist();
    });

    test("shows the button on read-only categories when setting is disabled", async function (assert) {
      this.siteSettings.hide_disabled_create_topic_button = false;

      await visit("/c/read-only-category");

      assert.dom("#create-topic").exists();
    });
  }
);
