import { test } from "qunit";
import { click, visit } from "@ember/test-helpers";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";

acceptance("User Preferences - Categories", function (needs) {
  needs.user();

  let putRequestData;

  needs.pretender((server, helper) => {
    server.put("/u/eviltrout.json", (request) => {
      putRequestData = helper.parsePostData(request.requestBody);
      return helper.response({ user: {} });
    });
  });

  needs.hooks.afterEach(() => {
    putRequestData = null;
  });

  test("tracking category which is set to regular notification level for user when mute_all_categories_by_default site setting is enabled", async function (assert) {
    this.siteSettings.mute_all_categories_by_default = true;

    await visit("/u/eviltrout/preferences/categories");

    const trackedCategoriesSelector = selectKit(
      ".tracking-controls__tracked-categories .category-selector"
    );

    await trackedCategoriesSelector.expand();

    assert.notOk(
      trackedCategoriesSelector.rowByValue("4").exists(),
      "category that is set to regular is not available for selection"
    );

    const regularCategoriesSelector = selectKit(
      ".tracking-controls__regular-categories .category-selector"
    );

    await trackedCategoriesSelector.collapse();

    await regularCategoriesSelector.expand();
    await regularCategoriesSelector.deselectItemByValue("4");

    await regularCategoriesSelector.collapse();
    await trackedCategoriesSelector.expand();
    await trackedCategoriesSelector.selectRowByValue("4");
    await trackedCategoriesSelector.collapse();

    await click(".save-changes");

    assert.deepEqual(putRequestData, {
      "regular_category_ids[]": ["-1"],
      "tracked_category_ids[]": ["4"],
      "watched_category_ids[]": ["3"],
      "watched_first_post_category_ids[]": ["-1"],
    });
  });

  test("tracking category which is set to regular notification level for user when mute_all_categories_by_default site setting is disabled", async function (assert) {
    await visit("/u/eviltrout/preferences/categories");

    const categorySelector = selectKit(
      ".tracking-controls__tracked-categories .category-selector"
    );

    await categorySelector.expand();
    // User has `regular_category_ids` set to [4] in fixtures
    await categorySelector.selectRowByValue(4);
    await categorySelector.collapse();
    await click(".save-changes");

    assert.deepEqual(putRequestData, {
      "muted_category_ids[]": ["-1"],
      "tracked_category_ids[]": ["4"],
      "watched_category_ids[]": ["3"],
      "watched_first_post_category_ids[]": ["-1"],
    });
  });
});
