import Service from "@ember/service";
import { click, find, render, settled, waitUntil } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import AiTranslations from "discourse/plugins/discourse-ai/discourse/components/ai-translations";

class AiCreditsStub extends Service {
  async getFeatureCreditStatus() {
    return null;
  }
}

const overview = {
  cached_at: "2026-07-23T09:00:00Z",
  targets: ["post", "topic", "category", "tag"].map((target_type) => ({
    target_type,
    total_count: 10,
    translated_count: 5,
    needs_language_detection_count: 2,
  })),
};

function detail(target_type, translated_count) {
  return {
    target_type,
    cached_at: "2026-07-23T09:00:00Z",
    locales: [
      {
        locale: "en",
        translated_count,
        pending_count: 10 - translated_count,
        eligible_count: 10,
      },
      {
        locale: "fr",
        translated_count,
        pending_count: 10 - translated_count,
        eligible_count: 10,
      },
    ],
  };
}

module("Integration | Component | AiTranslations", function (hooks) {
  setupRenderingTest(hooks, { stubRouter: true });

  hooks.beforeEach(function () {
    this.owner.unregister("service:ai-credits");
    this.owner.register("service:ai-credits", AiCreditsStub);

    this.siteSettings.content_localization_supported_locales = "en|fr";
    this.siteSettings.available_locales = [
      { name: "English", value: "en" },
      { name: "French", value: "fr" },
    ];
    this.model = {
      enabled: true,
      translation_enabled: true,
      no_locales_configured: false,
      backfill_enabled: false,
      category_scope: "public",
      category_ids: [],
      hourly_rate: 0,
      translation_id: 6,
    };

    pretender.get(
      "/admin/plugins/discourse-ai/ai-translations/progress.json",
      () => response(overview)
    );
  });

  test("keeps the current detail table open while another target loads", async function (assert) {
    let resolveTopic;

    pretender.get(
      "/admin/plugins/discourse-ai/ai-translations/progress/post.json",
      () => response(detail("post", 4))
    );
    pretender.get(
      "/admin/plugins/discourse-ai/ai-translations/progress/topic.json",
      () =>
        new Promise((resolve) => {
          resolveTopic = () => resolve(response(detail("topic", 7)));
        })
    );

    await render(<template><AiTranslations @model={{this.model}} /></template>);
    await click(
      ".ai-translation-model-progress-overview-card[data-target-type='post']"
    );

    find(
      ".ai-translation-model-progress-overview-card[data-target-type='topic']"
    ).click();
    await waitUntil(() => find(".ai-translation-model-progress-detail-state"));

    assert
      .dom(".ai-translation-model-progress-detail")
      .exists("the current detail table remains mounted");
    assert
      .dom(".ai-translation-model-progress-detail-state.--overlay")
      .exists("the loading state overlays the current table");

    resolveTopic();
    await settled();

    assert
      .dom(".ai-translation-locale-progress__translated-value")
      .hasText("7", "the newly loaded detail replaces the previous table");
  });

  test("does not reuse a detail response that finishes after disabling translations", async function (assert) {
    let resolveFirstRequest;
    let detailRequestCount = 0;

    pretender.get(
      "/admin/plugins/discourse-ai/ai-translations/progress/post.json",
      () => {
        detailRequestCount += 1;

        if (detailRequestCount === 1) {
          return new Promise((resolve) => {
            resolveFirstRequest = () => resolve(response(detail("post", 4)));
          });
        }

        return response(detail("post", 8));
      }
    );
    pretender.put("/admin/site_settings/ai_translation_enabled", () =>
      response({})
    );
    pretender.put("/admin/site_settings/content_localization_enabled", () =>
      response({})
    );

    await render(<template><AiTranslations @model={{this.model}} /></template>);

    find(
      ".ai-translation-model-progress-overview-card[data-target-type='post']"
    ).click();
    await waitUntil(() => resolveFirstRequest);

    find(
      ".ai-translations__toggle-container .d-toggle-switch__checkbox"
    ).click();
    await waitUntil(() => !find(".ai-translations__overview"));

    resolveFirstRequest();
    await settled();

    await click(
      ".ai-translations__toggle-container .d-toggle-switch__checkbox"
    );
    await click(
      ".ai-translation-model-progress-overview-card[data-target-type='post']"
    );

    assert.strictEqual(
      detailRequestCount,
      2,
      "the stale response is not retained in the frontend cache"
    );
    assert
      .dom(".ai-translation-locale-progress__translated-value")
      .hasText("8", "the refreshed response is rendered");
  });
});
