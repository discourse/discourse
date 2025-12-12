import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { withPluginApi } from "discourse/lib/plugin-api";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("preferences-save-attributes transformer", function (needs) {
  needs.user();

  let lastUserData;
  needs.pretender((server, helper) => {
    server.put("/u/eviltrout.json", (request) => {
      lastUserData = helper.parsePostData(request.requestBody);
      return helper.response({ user: {} });
    });
  });

  test("allows plugins to add attributes to the save list for a specific page", async function (assert) {
    // auto_track_topics_after_msecs is in userOptionFields but NOT in
    // the default saveAttrNames for the interface controller
    let transformerContext = null;
    withPluginApi((api) => {
      api.registerValueTransformer(
        "preferences-save-attributes",
        ({ value: attrs, context }) => {
          transformerContext = context;
          if (context.page === "interface") {
            attrs.push("auto_track_topics_after_msecs");
          }
          return attrs;
        }
      );
    });

    await visit("/u/eviltrout/preferences/interface");
    await click(".save-changes");

    assert.strictEqual(
      transformerContext.page,
      "interface",
      "transformer receives correct page context"
    );
    assert.true(
      "auto_track_topics_after_msecs" in lastUserData,
      "transformer-added attribute is included in save request"
    );
  });
});
