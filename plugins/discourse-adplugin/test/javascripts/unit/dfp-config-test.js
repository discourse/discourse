import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { withPluginApi } from "discourse/lib/plugin-api";
import { dfpConfig } from "discourse/plugins/discourse-adplugin/discourse/components/google-dfp-ad";

const SETTINGS = {
  dfp_publisher_id: "123456789",
  dfp_topic_list_top_code: "example.com/forums",
  dfp_target_topic_list_top_key_code: "gam_keywords",
  dfp_target_topic_list_top_value_code: "red,blue",
};

function context(overrides = {}) {
  return {
    categorySlug: "cards-talk",
    categoryPath: ["sports", "cards-talk"],
    categoryId: 41,
    routeName: "discovery.category",
    customFields: {},
    categoryConfig: {},
    ...overrides,
  };
}

module("Unit | Lib | dfp-config", function (hooks) {
  setupTest(hooks);

  test("uses the static settings by default", function (assert) {
    const config = dfpConfig(
      "topic-list-top",
      SETTINGS,
      false,
      context({ categorySlug: null })
    );

    assert.strictEqual(
      config.adUnitPath,
      "/123456789/example.com/forums",
      "ad unit path is built from the publisher id and placement code"
    );

    assert.deepEqual(
      config.targeting,
      { gam_keywords: ["red", "blue"], "discourse-category": "0" },
      "targeting comes from the dfp_target_* settings"
    );
  });

  test("uses category custom fields when present", function (assert) {
    const config = dfpConfig(
      "topic-list-top",
      SETTINGS,
      false,
      context({
        customFields: {
          gam_adunit: "/123456789/example.com/sports/forums/cards-talk",
          gam_keywords: "sports, mlb",
        },
      })
    );

    assert.strictEqual(
      config.adUnitPath,
      "/123456789/example.com/sports/forums/cards-talk",
      "gam_adunit overrides the configured ad unit path"
    );

    assert.deepEqual(
      config.targeting,
      {
        gam_keywords: ["sports", "mlb"],
        "discourse-category": "cards-talk",
      },
      "gam_keywords override the dfp_target_* values"
    );
  });

  test("falls back to settings when a category has no gam fields", function (assert) {
    const config = dfpConfig(
      "topic-list-top",
      SETTINGS,
      false,
      context({ customFields: { gtm_taxonomy: "sports/forums/cards-talk" } })
    );

    assert.strictEqual(config.adUnitPath, "/123456789/example.com/forums");

    assert.deepEqual(
      config.targeting,
      { gam_keywords: ["red", "blue"], "discourse-category": "cards-talk" },
      "non-gam custom fields do not affect the ad config"
    );
  });

  test("prefers centralized plugin settings over category custom fields", function (assert) {
    const config = dfpConfig(
      "topic-list-top",
      SETTINGS,
      false,
      context({
        customFields: {
          gam_adunit: "/123456789/from/custom-fields",
          gam_keywords: "custom,keywords",
        },
        categoryConfig: {
          gam_adunit: "/123456789/example.com/sports/forums/cards-talk",
          gam_keywords: "sports, mlb",
        },
      })
    );

    assert.strictEqual(
      config.adUnitPath,
      "/123456789/example.com/sports/forums/cards-talk",
      "the centralized plugin configuration wins"
    );

    assert.deepEqual(
      config.targeting,
      { gam_keywords: ["sports", "mlb"], "discourse-category": "cards-talk" },
      "centralized keywords replace category custom field keywords"
    );
  });

  test("applies overrides from a registered transformer", function (assert) {
    withPluginApi((api) => {
      api.registerValueTransformer(
        "dfp-ad-config",
        ({ value, context: ctx }) => {
          if (ctx.categorySlug === "cards-talk") {
            return {
              ...value,
              adUnitPath: "/123456789/example.com/sports/forums/cards-talk",
              targeting: { gam_keywords: ["sports", "mlb"] },
            };
          }

          return value;
        }
      );
    });

    const config = dfpConfig(
      "topic-list-top",
      SETTINGS,
      false,
      context({
        customFields: {
          gam_adunit: "/123456789/example.com/other/unit",
          gam_keywords: "from,fields",
        },
      })
    );

    assert.strictEqual(
      config.adUnitPath,
      "/123456789/example.com/sports/forums/cards-talk",
      "the transformer wins over category custom fields"
    );

    assert.deepEqual(
      config.targeting,
      { gam_keywords: ["sports", "mlb"], "discourse-category": "cards-talk" },
      "transformer targeting replaces the resolved values"
    );
  });

  test("keeps ad unit constant when only keywords change, dropping stale keywords", function (assert) {
    // Base targeting uses an unrelated key so gam_keywords only appears when a
    // category explicitly overrides it. This is the case the reused-slot bug
    // leaked: same ad unit across categories, keywords removed on navigation.
    const settings = {
      ...SETTINGS,
      dfp_target_topic_list_top_key_code: "geo",
      dfp_target_topic_list_top_value_code: "eu",
    };
    const unit = "/123456789/example.com/forums";

    const first = dfpConfig(
      "topic-list-top",
      settings,
      false,
      context({
        categorySlug: "sports",
        categoryConfig: { gam_adunit: unit, gam_keywords: "a,b" },
      })
    );
    assert.deepEqual(first.targeting.gam_keywords, ["a", "b"]);

    const second = dfpConfig(
      "topic-list-top",
      settings,
      false,
      context({
        categorySlug: "general",
        categoryConfig: { gam_adunit: unit },
      })
    );

    assert.strictEqual(
      second.adUnitPath,
      unit,
      "same ad unit path keeps the slot mounted (exercises the reuse branch)"
    );
    assert.false(
      "gam_keywords" in second.targeting,
      "a category with no keyword override returns no gam_keywords to clear on the reused slot"
    );
    assert.deepEqual(
      second.targeting.geo,
      ["eu"],
      "unrelated base targeting is preserved"
    );
  });
});
