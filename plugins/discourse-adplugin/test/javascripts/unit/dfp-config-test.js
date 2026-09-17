import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { withPluginApi } from "discourse/lib/plugin-api";
import { dfpConfig } from "discourse/plugins/discourse-adplugin/discourse/components/google-dfp-ad";

const SETTINGS = {
  dfp_publisher_id: "8438",
  dfp_topic_list_top_code: "stltoday.com/forums",
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
      "/8438/stltoday.com/forums",
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
          gam_adunit: "/8438/stltoday.com/sports/forums/cards-talk",
          gam_keywords: "sports, mlb, St. Louis Cardinals",
        },
      })
    );

    assert.strictEqual(
      config.adUnitPath,
      "/8438/stltoday.com/sports/forums/cards-talk",
      "gam_adunit overrides the configured ad unit path"
    );

    assert.deepEqual(
      config.targeting,
      {
        gam_keywords: ["sports", "mlb", "St. Louis Cardinals"],
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

    assert.strictEqual(config.adUnitPath, "/8438/stltoday.com/forums");

    assert.deepEqual(
      config.targeting,
      { gam_keywords: ["red", "blue"], "discourse-category": "cards-talk" },
      "non-gam custom fields do not affect the ad config"
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
              adUnitPath: "/8438/stltoday.com/sports/forums/cards-talk",
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
          gam_adunit: "/8438/stltoday.com/other/unit",
          gam_keywords: "from,fields",
        },
      })
    );

    assert.strictEqual(
      config.adUnitPath,
      "/8438/stltoday.com/sports/forums/cards-talk",
      "the transformer wins over category custom fields"
    );

    assert.deepEqual(
      config.targeting,
      { gam_keywords: ["sports", "mlb"], "discourse-category": "cards-talk" },
      "transformer targeting replaces the resolved values"
    );
  });
});
