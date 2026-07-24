import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";
import AiTranslationModelProgressOverviewCard from "discourse/plugins/discourse-ai/discourse/components/ai-translation-model-progress-overview-card";
import AiTranslationModelProgressOverviewSkeleton from "discourse/plugins/discourse-ai/discourse/components/ai-translation-model-progress-overview-skeleton";

module(
  "Integration | Component | ai-translation-model-progress-overview-card",
  function (hooks) {
    setupRenderingTest(hooks);

    test("renders eligible target counts and segmented progress", async function (assert) {
      const target = {
        target_type: "post",
        total_count: 474,
        translated_count: 215,
        needs_language_detection_count: 93,
      };

      await render(
        <template>
          <AiTranslationModelProgressOverviewCard
            @target={{target}}
            @expanded={{false}}
          />
        </template>
      );

      assert
        .dom(".ai-translation-model-progress-overview-card__title")
        .hasText("Posts");
      assert
        .dom(".ai-translation-model-progress-overview-card__percentage")
        .hasText("45%");
      assert
        .dom(".ai-translation-model-progress-overview-card__headline")
        .hasText("There are 474 eligible posts for translation.");
      assert
        .dom(".ai-translation-model-progress-overview-card__subheader")
        .exists({ count: 2 });
      assert
        .dom(".ai-translation-model-progress-overview-card__translated")
        .hasText("215 posts have been fully translated.");
      assert
        .dom(".ai-translation-model-progress-overview-card__needs-detection")
        .hasText("93 posts still need language detection.");
      assert
        .dom(".ai-translation-model-progress-overview-card__meter")
        .hasAttribute("aria-hidden", "true");
      assert
        .dom(".ai-translation-model-progress-overview-card")
        .hasAttribute("aria-expanded", "false");
    });

    test("uses the complete state while preserving card geometry", async function (assert) {
      const target = {
        target_type: "category",
        total_count: 18,
        translated_count: 18,
        needs_language_detection_count: 0,
      };

      await render(
        <template>
          <AiTranslationModelProgressOverviewCard
            @target={{target}}
            @expanded={{false}}
          />
        </template>
      );

      assert
        .dom(".ai-translation-model-progress-overview-card__headline")
        .hasText("All 18 eligible categories are fully translated.");
      assert
        .dom(".ai-translation-model-progress-overview-card__subheader")
        .exists({ count: 2 });
      assert
        .dom(".ai-translation-model-progress-overview-card__subheader")
        .hasAttribute("aria-hidden", "true");
    });

    test("does not describe tags as eligible", async function (assert) {
      const target = {
        target_type: "tag",
        total_count: 142,
        translated_count: 64,
        needs_language_detection_count: 7,
      };

      await render(
        <template>
          <AiTranslationModelProgressOverviewCard
            @target={{target}}
            @expanded={{false}}
          />
        </template>
      );

      assert
        .dom(".ai-translation-model-progress-overview-card__headline")
        .hasText("There are 142 tags for translation.");
      assert
        .dom(".ai-translation-model-progress-overview-card")
        .doesNotIncludeText("eligible");
    });
  }
);

module(
  "Integration | Component | ai-translation-model-progress-overview-skeleton",
  function (hooks) {
    setupRenderingTest(hooks);

    test("renders four accessible card placeholders", async function (assert) {
      await render(
        <template><AiTranslationModelProgressOverviewSkeleton /></template>
      );

      assert
        .dom(".ai-translation-model-progress-overview-skeleton")
        .hasAttribute("role", "status")
        .hasAria(
          "label",
          i18n("discourse_ai.translations.model_progress.loading")
        );
      assert
        .dom(".ai-translation-model-progress-overview-skeleton__card")
        .exists({ count: 4 });
    });
  }
);
