import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";

acceptance("User Preferences - Tracking", function (needs) {
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

  test("does not display user's tag notification levels when tagging is disabled", async function (assert) {
    this.siteSettings.tagging_enabled = false;

    await visit("/u/eviltrout/preferences/tracking");

    assert
      .dom(".tag-notifications")
      .doesNotExist("tag notification levels section is not displayed");
  });

  test("updating notification levels of tags when tagging is enabled", async function (assert) {
    this.siteSettings.tagging_enabled = true;

    await visit("/u/eviltrout/preferences/tracking");

    const trackedTagsSelector = selectKit(
      ".tracking-controls__tracked-tags .tag-chooser"
    );

    await trackedTagsSelector.expand();
    await trackedTagsSelector.selectRowByValue("monkey");

    const watchedTagsSelector = selectKit(
      ".tracking-controls__watched-tags .tag-chooser"
    );

    await watchedTagsSelector.expand();

    assert.false(
      watchedTagsSelector.rowByValue("monkey").exists(),
      "tag that has already been selected is not available for selection"
    );

    await watchedTagsSelector.selectRowByValue("gazelle");

    const mutedTagsSelector = selectKit(
      ".tracking-controls__muted-tags .tag-chooser"
    );

    await mutedTagsSelector.expand();

    ["monkey", "gazelle"].forEach((tagName) => {
      assert.false(
        mutedTagsSelector.rowByValue(tagName).exists(),
        `tag "${tagName}" has already been selected is not available for selection`
      );
    });

    await mutedTagsSelector.selectRowByValue("dog");

    const watchedFirstPostTagsSelector = selectKit(
      ".tracking-controls__watched-first-post-tags .tag-chooser"
    );

    await watchedFirstPostTagsSelector.expand();

    ["dog", "gazelle", "monkey"].forEach((tagName) => {
      assert.false(
        watchedFirstPostTagsSelector.rowByValue(tagName).exists(),
        "tag `${tagName}` has already been selected is not available for selection"
      );
    });

    await watchedFirstPostTagsSelector.selectRowByValue("cat");

    await click(".save-changes");

    assert.propContains(
      putRequestData,
      {
        muted_tags: "dog",
        tracked_tags: "monkey",
        watched_tags: "gazelle",
        watching_first_post_tags: "cat",
      },
      "request to server contains the right request params"
    );
  });

  test("updating notification levels of categories", async function (assert) {
    await visit("/u/eviltrout/preferences/tracking");

    const trackedCategoriesSelector = selectKit(
      ".tracking-controls__tracked-categories .category-selector"
    );

    await trackedCategoriesSelector.expand();

    assert.false(
      trackedCategoriesSelector.rowByValue("3").exists(),
      "category that has already been selected is not available for selection"
    );

    await trackedCategoriesSelector.selectRowByValue("4");

    const mutedCategoriesSelector = selectKit(
      ".tracking-controls__muted-categories .category-selector"
    );

    await mutedCategoriesSelector.expand();

    ["3", "4"].forEach((categoryId) => {
      assert.false(
        mutedCategoriesSelector.rowByValue(categoryId).exists(),
        `category id "${categoryId}" that has already been selected is not available for selection`
      );
    });

    await mutedCategoriesSelector.selectRowByValue("6");

    const watchedFirstCategoriesSelector = selectKit(
      ".tracking-controls__watched-first-categories .category-selector"
    );

    await watchedFirstCategoriesSelector.expand();

    ["3", "4", "6"].forEach((categoryId) => {
      assert.false(
        watchedFirstCategoriesSelector.rowByValue(categoryId).exists(),
        `category id "${categoryId}" that has already been selected is not available for selection`
      );
    });

    await watchedFirstCategoriesSelector.selectRowByValue("1");

    await click(".save-changes");

    assert.propContains(
      putRequestData,
      {
        "muted_category_ids[]": ["6"],
        "tracked_category_ids[]": ["4"],
        "watched_category_ids[]": ["3"],
        "watched_first_post_category_ids[]": ["1"],
      },
      "request to server contains the right request params"
    );
  });

  test("tracking category which is set to regular notification level for user when mute_all_categories_by_default site setting is enabled", async function (assert) {
    this.siteSettings.tagging_enabled = false;
    this.siteSettings.mute_all_categories_by_default = true;

    await visit("/u/eviltrout/preferences/tracking");

    const trackedCategoriesSelector = selectKit(
      ".tracking-controls__tracked-categories .category-selector"
    );

    await trackedCategoriesSelector.expand();

    assert.false(
      trackedCategoriesSelector.rowByValue("4").exists(),
      "category that is set to regular is not available for selection"
    );

    const regularCategoriesSelector = selectKit(
      ".tracking-controls__regular-categories .category-selector"
    );

    await regularCategoriesSelector.expand();
    await regularCategoriesSelector.deselectItemByValue("4");
    await trackedCategoriesSelector.expand();
    await trackedCategoriesSelector.selectRowByValue("4");
    await click(".save-changes");

    assert.deepEqual(putRequestData, {
      auto_track_topics_after_msecs: "60000",
      new_topic_duration_minutes: "1440",
      "regular_category_ids[]": ["-1"],
      "tracked_category_ids[]": ["4"],
      "watched_category_ids[]": ["3"],
      "watched_first_post_category_ids[]": ["-1"],
    });
  });

  test("additional precedence option when one category is watched and tag is muted", async function (assert) {
    this.siteSettings.tagging_enabled = true;

    await visit("/u/eviltrout/preferences/tracking");

    const mutedTagsSelector = selectKit(
      ".tracking-controls__muted-tags .tag-chooser"
    );

    assert.dom(".user-preferences__watched-precedence-over-muted").doesNotExist;
    await mutedTagsSelector.expand();
    await mutedTagsSelector.selectRowByValue("dog");

    assert.dom(".user-preferences__watched-precedence-over-muted").exists();
  });

  test("tracking category which is set to regular notification level for user when mute_all_categories_by_default site setting is disabled", async function (assert) {
    this.siteSettings.tagging_enabled = false;

    await visit("/u/eviltrout/preferences/tracking");

    const categorySelector = selectKit(
      ".tracking-controls__tracked-categories .category-selector"
    );

    await categorySelector.expand();
    // User has `regular_category_ids` set to [4] in fixtures
    await categorySelector.selectRowByValue(4);
    await click(".save-changes");

    assert.deepEqual(putRequestData, {
      auto_track_topics_after_msecs: "60000",
      new_topic_duration_minutes: "1440",
      "muted_category_ids[]": ["-1"],
      "tracked_category_ids[]": ["4"],
      "watched_category_ids[]": ["3"],
      "watched_first_post_category_ids[]": ["-1"],
    });
  });
});
