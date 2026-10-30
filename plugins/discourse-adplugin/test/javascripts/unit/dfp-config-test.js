import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { withPluginApi } from "discourse/lib/plugin-api";
import { dfpConfig } from "discourse/plugins/discourse-adplugin/discourse/components/google-dfp-ad";

const SETTINGS = {
  dfp_publisher_id: "6355419",
  dfp_topic_list_top_code: "Travel",
  dfp_target_topic_list_top_key_code: "gam_keywords",
  dfp_target_topic_list_top_value_code: "red,blue",
};

function context(overrides = {}) {
  return {
    categorySlug: "paris",
    categoryPath: ["travel", "paris"],
    categoryId: 41,
    routeName: "discovery.category",
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
      "/6355419/Travel",
      "ad unit path is built from the publisher id and placement code"
    );

    assert.deepEqual(
      config.targeting,
      { gam_keywords: ["red", "blue"], "discourse-category": "0" },
      "targeting comes from the dfp_target_* settings"
    );
  });

  test("uses the dashboard config when present", function (assert) {
    const config = dfpConfig(
      "topic-list-top",
      SETTINGS,
      false,
      context({
        categoryConfig: {
          gam_adunit: "/6355419/Travel/Europe/France/Paris",
          gam_keywords: "travel, europe",
        },
      })
    );

    assert.strictEqual(
      config.adUnitPath,
      "/6355419/Travel/Europe/France/Paris",
      "gam_adunit overrides the configured ad unit path"
    );

    assert.deepEqual(
      config.targeting,
      { gam_keywords: ["travel", "europe"], "discourse-category": "paris" },
      "gam_keywords override the dfp_target_* values"
    );
  });

  test("ignores a dashboard config that sets no ad fields", function (assert) {
    const config = dfpConfig(
      "topic-list-top",
      SETTINGS,
      false,
      context({
        categoryConfig: { gtm_taxonomy: "travel/europe/france/paris" },
      })
    );

    assert.strictEqual(config.adUnitPath, "/6355419/Travel");

    assert.deepEqual(
      config.targeting,
      { gam_keywords: ["red", "blue"], "discourse-category": "paris" },
      "non-GAM fields do not affect the ad config"
    );
  });

  test("the transformer overrides the dashboard config", function (assert) {
    withPluginApi((api) => {
      api.registerValueTransformer(
        "dfp-ad-config",
        ({ value, context: ctx }) => {
          if (ctx.categorySlug === "paris") {
            return {
              ...value,
              adUnitPath: "/6355419/Travel/Transformer",
              targeting: { gam_keywords: ["custom"] },
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
        categoryConfig: {
          gam_adunit: "/6355419/Travel/Europe/France/Paris",
          gam_keywords: "travel, europe",
        },
      })
    );

    assert.strictEqual(
      config.adUnitPath,
      "/6355419/Travel/Transformer",
      "the transformer wins over the dashboard config"
    );

    assert.deepEqual(
      config.targeting,
      { gam_keywords: ["custom"], "discourse-category": "paris" },
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
    const unit = "/6355419/Travel";

    const first = dfpConfig(
      "topic-list-top",
      settings,
      false,
      context({
        categorySlug: "travel",
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
