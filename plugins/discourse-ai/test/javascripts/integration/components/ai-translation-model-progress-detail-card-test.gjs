import { render, settled, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import AiTranslationModelProgressDetailCard from "discourse/plugins/discourse-ai/discourse/components/ai-translation-model-progress-detail-card";

module(
  "Integration | Component | ai-translation-model-progress-detail-card",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.siteSettings.available_locales = [
        { name: "English", value: "en" },
        { name: "French", value: "fr" },
      ];
    });

    test("renders locale progress with eligible and pending help", async function (assert) {
      const data = {
        target_type: "post",
        locales: [
          {
            locale: "en",
            translated_count: 215,
            pending_count: 93,
            eligible_count: 474,
          },
          {
            locale: "fr",
            translated_count: 30,
            pending_count: 20,
            eligible_count: 50,
          },
        ],
      };

      await render(
        <template>
          <AiTranslationModelProgressDetailCard @data={{data}} />
        </template>
      );

      assert.dom(".ai-translation-model-progress-detail").exists();
      assert.dom(".ai-translation-locale-progress__row").exists({ count: 2 });
      assert
        .dom(".ai-translation-locale-progress__locale-code")
        .exists({ count: 2 });
      assert
        .dom(".ai-translation-locale-progress__translated-value")
        .hasText("215");
      assert
        .dom(".ai-translation-locale-progress__pending-value")
        .hasText("93");
      assert
        .dom(".ai-translation-locale-progress__denominator-value")
        .hasText("474");
      assert
        .dom(".ai-translation-progress-bar")
        .hasAttribute("role", "progressbar")
        .hasAria("label", "215 of 474 translated into English")
        .hasAria("valuenow", "45")
        .hasAria("valuemin", "0")
        .hasAria("valuemax", "100");
      assert.dom(".fk-d-tooltip__trigger").exists({ count: 2 });

      await triggerEvent(
        ".ai-translation-locale-progress__pending-header .fk-d-tooltip__trigger",
        "pointermove"
      );
      assert
        .dom(".fk-d-tooltip__content")
        .includesText(
          "Includes eligible posts that do not have language detected yet."
        );
    });

    test("uses total for tags without eligibility help", async function (assert) {
      const data = {
        target_type: "tag",
        locales: [
          {
            locale: "en",
            translated_count: 10,
            pending_count: 5,
            total_count: 15,
          },
        ],
      };

      await render(
        <template>
          <AiTranslationModelProgressDetailCard @data={{data}} />
        </template>
      );

      assert
        .dom(".ai-translation-locale-progress__denominator-header")
        .hasText("Total");
      assert
        .dom(
          ".ai-translation-locale-progress__denominator-header .fk-d-tooltip__trigger"
        )
        .doesNotExist();
      assert
        .dom(".ai-translation-locale-progress__denominator-value")
        .hasText("15");
    });

    test("excludes pending when its values are nil", async function (assert) {
      const data = {
        target_type: "category",
        locales: [
          {
            locale: "en",
            translated_count: 10,
            pending_count: null,
            eligible_count: 15,
          },
        ],
      };

      await render(
        <template>
          <AiTranslationModelProgressDetailCard @data={{data}} />
        </template>
      );

      assert
        .dom(".ai-translation-locale-progress__pending-header")
        .doesNotExist();
      assert.dom(".ai-translation-locale-progress__pending").doesNotExist();
    });

    test("renders an empty state when no locale details are available", async function (assert) {
      const data = { target_type: "post", locales: [] };

      await render(
        <template>
          <AiTranslationModelProgressDetailCard @data={{data}} />
        </template>
      );

      assert
        .dom(".ai-translation-model-progress-detail__empty")
        .hasText("No language progress is available.");
    });

    test("updates tooltips and columns when the target changes", async function (assert) {
      this.set("data", {
        target_type: "post",
        locales: [
          {
            locale: "en",
            translated_count: 10,
            pending_count: 5,
            eligible_count: 15,
          },
        ],
      });

      await render(
        <template>
          <AiTranslationModelProgressDetailCard @data={{this.data}} />
        </template>
      );

      assert
        .dom(".ai-translation-locale-progress__denominator-header")
        .includesText("Eligible");
      assert.dom(".fk-d-tooltip__trigger").exists({ count: 2 });

      this.set("data", {
        target_type: "tag",
        locales: [
          {
            locale: "en",
            translated_count: 10,
            pending_count: 5,
            total_count: 15,
          },
        ],
      });
      await settled();

      assert
        .dom(".ai-translation-locale-progress__denominator-header")
        .hasText("Total");
      assert.dom(".fk-d-tooltip__trigger").exists({ count: 1 });
    });
  }
);
