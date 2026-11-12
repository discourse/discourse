import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { withPluginApi } from "discourse/lib/plugin-api";
import DiscoveryFixtures from "discourse/tests/fixtures/discovery-fixtures";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("can-create-topic-button transformer", function (needs) {
  needs.user();
  needs.pretender((server, helper) => {
    server.get("/c/writable-category/7/l/latest.json", () => {
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
    ],
  });

  test("renders the button by default", async function (assert) {
    await visit("/latest");

    assert.dom("#create-topic").exists();
  });

  test("hides the button when the transformer returns false", async function (assert) {
    withPluginApi((api) => {
      api.registerValueTransformer("can-create-topic-button", () => false);
    });

    await visit("/latest");

    assert.dom("#create-topic").doesNotExist();
  });

  test("the transformer receives the category from the route as context", async function (assert) {
    withPluginApi((api) => {
      api.registerValueTransformer(
        "can-create-topic-button",
        ({ value, context }) => {
          if (!context.category && !context.tag) {
            return false;
          }

          return value;
        }
      );
    });

    await visit("/latest");
    assert
      .dom("#create-topic")
      .doesNotExist("hidden when there is no category context");

    await visit("/c/writable-category");
    assert
      .dom("#create-topic")
      .exists("visible when there is a category context");
  });
});
