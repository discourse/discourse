import { module, test } from "qunit";
import { getSettingGroupsForFeature } from "discourse/plugins/discourse-ai/discourse/lib/ai-feature-setting-groups";

module("Unit | Lib | ai-feature-setting-groups", function () {
  test("returns correct groups for ai_helper", function (assert) {
    const groups = getSettingGroupsForFeature("ai_helper");

    assert.strictEqual(groups.length, 4, "ai_helper should have 4 groups");
    assert.strictEqual(
      groups[0].key,
      "access_permissions",
      "first group should be access_permissions"
    );

    assert.true(
      groups[0].settings.includes("ai_helper_enabled"),
      "access_permissions should include ai_helper_enabled"
    );
  });

  test("returns correct groups for embeddings", function (assert) {
    const groups = getSettingGroupsForFeature("embeddings");

    assert.strictEqual(groups.length, 3, "embeddings should have 3 groups");
    assert.strictEqual(
      groups[0].key,
      "model_settings",
      "first group should be model_settings"
    );
  });

  test("returns correct groups for bot", function (assert) {
    const groups = getSettingGroupsForFeature("bot");

    assert.strictEqual(groups.length, 4, "bot should have 4 groups");
    assert.strictEqual(
      groups[0].key,
      "settings",
      "first group should be settings"
    );
  });

  test("returns correct groups for summarization", function (assert) {
    const groups = getSettingGroupsForFeature("summarization");

    assert.strictEqual(groups.length, 3, "summarization should have 3 groups");
  });

  test("returns correct groups for search", function (assert) {
    const groups = getSettingGroupsForFeature("search");

    assert.strictEqual(groups.length, 1, "search should have 1 group");
  });

  test("returns correct groups for translation", function (assert) {
    const groups = getSettingGroupsForFeature("translation");

    assert.strictEqual(groups.length, 3, "translation should have 3 groups");
  });

  test("returns correct groups for discord", function (assert) {
    const groups = getSettingGroupsForFeature("discord");

    assert.strictEqual(groups.length, 2, "discord should have 2 groups");
  });

  test("returns correct groups for inference", function (assert) {
    const groups = getSettingGroupsForFeature("inference");

    assert.strictEqual(groups.length, 4, "inference should have 4 groups");
  });

  test("returns empty array for unknown feature", function (assert) {
    const groups = getSettingGroupsForFeature("unknown_feature");

    assert.strictEqual(
      groups.length,
      0,
      "unknown feature should return empty array"
    );
  });
});
