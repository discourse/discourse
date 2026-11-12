import Service from "@ember/service";
import { click, find, render, settled, waitUntil } from "@ember/test-helpers";
import { module, test } from "qunit";
import SiteSetting from "discourse/admin/models/site-setting";
import DialogHolder from "discourse/dialog-holder/components/dialog-holder";
import { forceMobile } from "discourse/lib/mobile";
import { extraConnectorComponent } from "discourse/lib/plugin-connectors";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import form from "discourse/tests/helpers/form-kit-helper";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { i18n } from "discourse-i18n";
import AiTranslations from "discourse/plugins/discourse-ai/discourse/components/ai-translations";
import { TRANSLATION_SETTING_NAMES } from "discourse/plugins/discourse-ai/discourse/lib/ai-translation-settings";

class AiCreditsStub extends Service {
  async getFeatureCreditStatus() {
    return null;
  }
}

function refreshSettings(settings, values) {
  return settings.map((setting) =>
    SiteSetting.create({
      ...setting.getProperties(
        "setting",
        "humanized_name",
        "description",
        "type",
        "default",
        "valid_values",
        "depends_on",
        "depends_behavior",
        "depends_on_values"
      ),
      value: values[setting.setting],
    })
  );
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
    this.siteSettings.content_localization_enabled = false;
    this.siteSettings.content_localization_language_switcher = "none";
    this.owner.lookup("service:router").refresh = () => {};
    const values = {
      content_localization_supported_locales: "en|fr",
      content_localization_enabled: false,
      allow_user_locale: true,
      content_localization_language_switcher: "none",
      set_locale_from_param: false,
      content_localization_crawler_param: false,
      content_localization_use_default_locale_when_unsupported: true,
      ai_translation_category_scope: "public",
      ai_translation_categories: "",
      ai_translation_personal_messages: "none",
      ai_translation_include_bot_content: false,
      ai_translation_backfill_start_date: "",
      ai_translation_backfill_hourly_rate: 50,
      ai_translation_verbose_logs: false,
    };
    const settings = TRANSLATION_SETTING_NAMES.map((name) =>
      SiteSetting.create({
        setting: name,
        humanized_name: name[0].toUpperCase() + name.slice(1),
        description: name,
        type:
          typeof values[name] === "boolean"
            ? "bool"
            : name === "ai_translation_backfill_hourly_rate"
              ? "integer"
              : "string",
        value: values[name] ?? "",
        default: "",
      })
    );
    const scope = settings.find(
      (setting) => setting.setting === "ai_translation_category_scope"
    );
    scope.type = "enum";
    scope.valid_values = ["public", "all", "include", "exclude"];
    const categories = settings.find(
      (setting) => setting.setting === "ai_translation_categories"
    );
    categories.type = "category_list";
    categories.depends_behavior = "hidden";
    categories.depends_on = ["ai_translation_category_scope"];
    categories.depends_on_values = {
      ai_translation_category_scope: ["include", "exclude"],
    };
    this.model = {
      enabled: true,
      translation_enabled: true,
      backfill_enabled: false,
      hourly_rate: 0,
      settings,
      formData: Object.fromEntries(
        settings.map((setting) => [setting.setting, setting.value])
      ),
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
    let translationEnabled = true;

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
    pretender.put("/admin/site_settings/ai_translation_enabled", (request) => {
      translationEnabled =
        new URLSearchParams(request.requestBody).get(
          "ai_translation_enabled"
        ) === "true";
      return response({});
    });
    this.owner.lookup("service:router").refresh = () => {
      this.set("model", {
        ...this.model,
        translation_enabled: translationEnabled,
        enabled: translationEnabled,
      });
    };

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

  test("disables enabling until supported languages are saved", async function (assert) {
    this.model.translation_enabled = false;
    this.model.enabled = false;
    this.siteSettings.content_localization_supported_locales = "";
    this.model.formData.content_localization_supported_locales = "";
    this.model.settings.find(
      (setting) => setting.setting === "content_localization_supported_locales"
    ).value = "";
    pretender.put(
      "/admin/site_settings/content_localization_supported_locales",
      () => response({})
    );

    await render(<template><AiTranslations @model={{this.model}} /></template>);
    const toggle = ".ai-translations__toggle-container [role='switch']";
    assert.dom(toggle).isDisabled("no saved languages prevents enabling");
    assert
      .dom(".ai-translations__toggle-hint")
      .hasText(
        i18n(
          "discourse_ai.translations.admin_actions.enable_translations_disabled"
        ),
        "a visible explanation accompanies the disabled switch"
      );
    const locales = selectKit(".ai-translations__locales .multi-select");
    await locales.expand();
    await locales.selectRowByValue("en");
    assert
      .dom(toggle)
      .isDisabled("an unsaved language does not allow enabling");
    await form().submit();
    assert.dom(toggle).isNotDisabled("saving languages allows enabling");
    assert.false(
      this.siteSettings.content_localization_enabled,
      "saving languages does not expose translations to readers"
    );
  });

  test("allows disabling AI translation even without supported languages", async function (assert) {
    this.siteSettings.content_localization_supported_locales = "";
    pretender.put("/admin/site_settings/ai_translation_enabled", () =>
      response({})
    );
    await render(<template><AiTranslations @model={{this.model}} /></template>);
    assert
      .dom("[role='switch']")
      .isNotDisabled("an enabled switch can always be turned off");
    await click("[role='switch']");
    assert
      .dom("[role='switch']")
      .hasAttribute("aria-checked", "false", "AI translation is off");
  });

  test("shows the locale count and blocks selections beyond the max", async function (assert) {
    this.siteSettings.content_localization_max_locales = 2;
    this.siteSettings.available_locales = [
      { name: "English", value: "en" },
      { name: "French", value: "fr" },
      { name: "Spanish", value: "es" },
    ];

    await render(<template><AiTranslations @model={{this.model}} /></template>);

    assert
      .dom(".ai-translations__locale-count")
      .hasText(
        i18n("discourse_ai.translations.locale_count", { count: 2, max: 2 }),
        "renders the locale usage count"
      );

    const locales = selectKit(".ai-translations__locales .multi-select");
    await locales.expand();
    await locales.selectRowByValue("es");

    const toasts = this.owner.lookup("service:toasts");
    assert.strictEqual(
      toasts.activeToasts.length,
      1,
      "selecting a locale beyond the max shows a toast"
    );
    assert.strictEqual(
      toasts.activeToasts[0].options.data.message,
      i18n("discourse_ai.translations.max_locales_reached", { max: 2 }),
      "the toast explains the limit"
    );

    assert.strictEqual(
      locales.header().value(),
      "en,fr",
      "the selection is unchanged"
    );
    assert
      .dom(".ai-translations__locale-count")
      .hasText(
        i18n("discourse_ai.translations.locale_count", { count: 2, max: 2 }),
        "the count is unchanged"
      );
    assert.form().hasNoErrors("the rejected selection leaves the form valid");
  });

  test("keeps the locale-info outlet and its arguments", async function (assert) {
    this.siteSettings.content_localization_max_locales = 3;
    extraConnectorComponent(
      "ai-translations-locale-info",
      <template>
        <span class="locale-info-test">{{@localesCount}}/{{@maxLocales}}</span>
      </template>
    );
    await render(<template><AiTranslations @model={{this.model}} /></template>);
    assert
      .dom(".locale-info-test")
      .hasText("2/3", "extensions receive the draft locale count and limit");
    this.siteSettings.content_localization_max_locales = 0;
    await settled();
    assert
      .dom(".ai-translations__locale-count")
      .doesNotExist("no count is shown without a limit");
    assert
      .dom(".locale-info-test")
      .hasText("2/0", "the outlet remains available without a limit");
  });

  test("the enabled switch only saves the AI translation setting", async function (assert) {
    this.model.translation_enabled = false;
    this.model.enabled = false;
    const updates = [];
    pretender.put("/admin/site_settings/:name", (request) => {
      updates.push([
        request.params.name,
        new URLSearchParams(request.requestBody).get(request.params.name),
      ]);
      return response({});
    });
    await render(<template><AiTranslations @model={{this.model}} /></template>);
    await click("[role='switch']");
    assert.deepEqual(
      updates,
      [["ai_translation_enabled", "true"]],
      "enabling sends only the AI flag"
    );
    assert.false(
      this.siteSettings.content_localization_enabled,
      "reader visibility stays off"
    );
    assert.strictEqual(
      this.siteSettings.content_localization_language_switcher,
      "none",
      "the language switcher stays off"
    );
    assert
      .dom(".ai-translations__readers-notice a")
      .hasAttribute(
        "href",
        "#ai-translations-readers",
        "the hidden notice points to Readers"
      );

    this.siteSettings.content_localization_enabled = true;
    await settled();
    assert
      .dom(".ai-translations__readers-notice")
      .doesNotExist("visible translations need no notice");
    await click("[role='switch']");
    assert.deepEqual(
      updates[1],
      ["ai_translation_enabled", "false"],
      "disabling sends only the AI flag"
    );
    assert.true(
      this.siteSettings.content_localization_enabled,
      "existing translations remain visible"
    );
  });

  test("saves changed fields and updates client settings and progress", async function (assert) {
    const updates = [];
    let progressRequests = 0;
    pretender.get(
      "/admin/plugins/discourse-ai/ai-translations/progress.json",
      () => {
        progressRequests++;
        return response(overview);
      }
    );
    pretender.put("/admin/site_settings/:name", (request) => {
      updates.push([
        request.params.name,
        new URLSearchParams(request.requestBody).get(request.params.name),
      ]);
      return response({});
    });
    await render(<template><AiTranslations @model={{this.model}} /></template>);
    const initialProgressRequests = progressRequests;
    await form().field("content_localization_enabled").toggle();
    await form().field("ai_translation_backfill_hourly_rate").fillIn(75);
    await form().submit();
    assert.deepEqual(
      Object.fromEntries(updates),
      {
        content_localization_enabled: "true",
        ai_translation_backfill_hourly_rate: "75",
      },
      "only changed settings are submitted"
    );
    assert.true(
      this.siteSettings.content_localization_enabled,
      "the client setting is synchronized"
    );
    assert
      .dom(".ai-translations__readers-notice")
      .doesNotExist("the notice reflects the saved reader setting");
    assert.true(
      progressRequests > initialProgressRequests,
      "saving refreshes the progress overview"
    );
  });

  test("toggling generation preserves unsaved form edits across model replacement", async function (assert) {
    this.owner.lookup("service:router").refresh = () => {
      this.set("model", {
        ...this.model,
        translation_enabled: false,
        enabled: false,
        formData: { ...this.model.formData },
        settings: refreshSettings(this.model.settings, this.model.formData),
      });
    };
    pretender.put("/admin/site_settings/ai_translation_enabled", () =>
      response({})
    );
    await render(<template><AiTranslations @model={{this.model}} /></template>);
    await form().field("ai_translation_backfill_hourly_rate").fillIn(75);
    await click("[role='switch']");
    assert
      .dom("[role='switch']")
      .hasAria("checked", "false", "the header follows the server");
    assert
      .form()
      .field("ai_translation_backfill_hourly_rate")
      .hasValue("75", "the unsaved draft survives the refresh");
  });

  test("enabling generation synchronizes server-initialized settings without overwriting drafts", async function (assert) {
    const date = "2026-11-06";
    const updates = [];
    this.model.translation_enabled = false;
    this.model.enabled = false;
    this.owner.lookup("service:router").refresh = () => {
      const formData = {
        ...this.model.formData,
        ai_translation_backfill_start_date: date,
      };
      this.set("model", {
        ...this.model,
        translation_enabled: true,
        enabled: true,
        formData,
        settings: refreshSettings(this.model.settings, formData),
      });
    };
    pretender.put("/admin/site_settings/:name", (request) => {
      updates.push(request.params.name);
      return response({});
    });
    await render(<template><AiTranslations @model={{this.model}} /></template>);
    await form().field("ai_translation_backfill_hourly_rate").fillIn(75);
    await click("[role='switch']");
    assert
      .form()
      .field("ai_translation_backfill_start_date")
      .hasValue(
        date,
        "the clean date field adopts the server's initialized cutoff"
      );
    assert
      .form()
      .field("ai_translation_backfill_hourly_rate")
      .hasValue("75", "the dirty field keeps the admin's draft");
    await form().submit();
    assert.deepEqual(
      updates,
      ["ai_translation_enabled", "ai_translation_backfill_hourly_rate"],
      "saving another setting does not erase the initialized cutoff"
    );
  });

  test("retains rejected drafts and inline errors when a save refreshes the model", async function (assert) {
    this.owner.lookup("service:router").refresh = () => {
      this.set("model", {
        ...this.model,
        formData: { ...this.model.formData },
        settings: refreshSettings(this.model.settings, this.model.formData),
      });
    };
    pretender.put(
      "/admin/site_settings/ai_translation_backfill_hourly_rate",
      () => response(422, { errors: ["Invalid rate"] })
    );
    await render(<template><AiTranslations @model={{this.model}} /></template>);
    await form().field("ai_translation_backfill_hourly_rate").fillIn(75);
    await form().submit();
    assert.form().hasErrors(
      {
        ai_translation_backfill_hourly_rate: "Invalid rate",
      },
      "the server error remains attached to the field after refresh"
    );
    assert
      .form()
      .field("ai_translation_backfill_hourly_rate")
      .hasValue("75", "keeps the rejected value for correction");
  });

  test("shows categories only for a selected category scope and collapses agents", async function (assert) {
    await render(<template><AiTranslations @model={{this.model}} /></template>);
    assert
      .form()
      .field("ai_translation_categories")
      .doesNotExist("public scope hides the category list");
    await form().field("ai_translation_category_scope").fillIn("include");
    assert
      .form()
      .field("ai_translation_categories")
      .exists("include scope shows the category list");
    assert
      .dom(".ai-translations__agents")
      .doesNotHaveAttribute("open", "agents start collapsed");
    await click(".ai-translations__agents summary");
    assert
      .form()
      .field("ai_translation_locale_detector_agent")
      .exists("agent settings remain editable");
  });

  test("keeps the switch accessible in the mobile header actions", async function (assert) {
    forceMobile();
    await render(<template><AiTranslations @model={{this.model}} /></template>);
    await click(".d-page-subheader__actions .btn");
    assert
      .dom(".d-page-subheader__mobile-actions li [role='switch']")
      .hasAttribute(
        "aria-checked",
        "true",
        "the mobile action menu contains the current enabled state"
      );
    assert
      .dom(".d-toggle-switch__checkbox-label")
      .hasText(
        i18n("discourse_ai.translations.admin_actions.enabled"),
        "the switch has a visible accessible label"
      );
  });

  test("keeps the credit-limit warning", async function (assert) {
    this.owner.lookup("service:ai-credits").getFeatureCreditStatus =
      async () => ({ hard_limit_reached: true });
    await render(<template><AiTranslations @model={{this.model}} /></template>);
    assert
      .dom(".ai-translations__credit-warning")
      .hasText(
        i18n("discourse_ai.translations.credit_limit_warning_no_time"),
        "credit limits still explain why translations are paused"
      );
  });

  test("renders every setting once, with hidden settings omitted", async function (assert) {
    this.model.formData.ai_translation_category_scope = "include";
    this.model.formData.set_locale_from_param = true;
    await render(<template><AiTranslations @model={{this.model}} /></template>);
    for (const name of TRANSLATION_SETTING_NAMES) {
      assert
        .dom(`[data-name='${name}']`)
        .exists({ count: 1 }, `${name} is editable exactly once`);
    }
    assert
      .dom("[role='switch']")
      .exists({ count: 1 }, "the AI flag has one header control");
    assert
      .dom("[data-name='ai_translation_enabled']")
      .doesNotExist("the AI flag is not duplicated in the form");
    assert
      .dom("[data-name='ai_translation_backfill_parallel_jobs']")
      .doesNotExist("internal settings stay hidden");
    assert
      .dom("[data-name='ai_translation_verbose_logs']")
      .exists("verbose logging is still reachable from translations");
    assert
      .dom("button[type='submit']")
      .hasText(i18n("save"), "the form has one Save button");
  });

  test("offers settings only once the settings they require are on", async function (assert) {
    await render(<template><AiTranslations @model={{this.model}} /></template>);

    assert
      .dom("[data-name='content_localization_crawler_param']")
      .doesNotExist("search engine indexing needs language links");

    await click("[data-name='set_locale_from_param'] input");

    assert.dom("[data-name='content_localization_crawler_param']").exists();

    await click("[data-name='allow_user_locale'] input");

    for (const name of [
      "set_locale_from_param",
      "content_localization_language_switcher",
      "content_localization_crawler_param",
    ]) {
      assert
        .dom(`[data-name='${name}']`)
        .doesNotExist(`${name} needs users to choose a language`);
    }
  });

  test("preserves the switch state when its save fails", async function (assert) {
    this.model.translation_enabled = false;
    this.model.enabled = false;
    pretender.put("/admin/site_settings/ai_translation_enabled", () =>
      response(422, { errors: ["Cannot enable translations"] })
    );
    await render(
      <template>
        <DialogHolder /><AiTranslations @model={{this.model}} />
      </template>
    );
    await click("[role='switch']");
    assert
      .dom("[role='switch']")
      .hasAttribute(
        "aria-checked",
        "false",
        "a failed save leaves generation off"
      );
    assert
      .dom(".dialog-body")
      .includesText(
        "Cannot enable translations",
        "the server error is shown in a popup"
      );
  });

  test("saves supported languages before dependent reader settings", async function (assert) {
    const updates = [];
    this.model.formData.content_localization_supported_locales = "";
    this.model.settings.find(
      (setting) => setting.setting === "content_localization_supported_locales"
    ).value = "";
    this.model.formData.content_localization_language_switcher = "none";
    pretender.put("/admin/site_settings/:name", (request) => {
      updates.push(request.params.name);
      return response({});
    });
    await render(<template><AiTranslations @model={{this.model}} /></template>);
    // Edit dependents first to exercise draft data's insertion order.
    await form().field("content_localization_language_switcher").fillIn("all");
    const locales = selectKit(".ai-translations__locales .multi-select");
    await locales.expand();
    await locales.selectRowByValue("en");
    await form().submit();
    assert.deepEqual(
      updates,
      [
        "content_localization_supported_locales",
        "content_localization_language_switcher",
      ],
      "prerequisites save first regardless of edit order"
    );
  });

  test("shows the fixed backfill start date", async function (assert) {
    const backfillStartDate = "2026-07-01";
    const formattedDate = new Date(backfillStartDate).toLocaleDateString(
      undefined,
      {
        year: "numeric",
        month: "long",
        day: "numeric",
        timeZone: "UTC",
      }
    );
    this.model = {
      ...this.model,
      backfill_enabled: true,
      backfill_start_date: backfillStartDate,
      hourly_rate: 50,
    };

    await render(<template><AiTranslations @model={{this.model}} /></template>);

    assert
      .dom(".ai-translations__stat-label")
      .includesText(
        formattedDate,
        "the status uses the configured fixed cutoff date"
      );
    assert
      .dom(".ai-translations__stat-label a")
      .hasAttribute(
        "href",
        "#ai-translations-backfill",
        "backfill links stay on this page"
      );
  });

  test("does not submit a dependent setting that a parent change hid", async function (assert) {
    const updates = [];
    pretender.put("/admin/site_settings/:name", (request) => {
      updates.push([
        request.params.name,
        new URLSearchParams(request.requestBody).get(request.params.name),
      ]);
      return response({});
    });

    await render(<template><AiTranslations @model={{this.model}} /></template>);
    await form().field("content_localization_language_switcher").fillIn("all");
    await form().field("allow_user_locale").toggle();

    assert
      .form()
      .field("content_localization_language_switcher")
      .doesNotExist("the switcher is no longer offered");

    await form().submit();

    assert.deepEqual(
      Object.fromEntries(updates),
      { allow_user_locale: "false" },
      "the hidden setting's stale draft value is not submitted"
    );
    assert
      .dom(".form-kit__errors-summary")
      .doesNotExist("the server rejects no hidden field");
  });

  test("uses the server's readiness after saving settings", async function (assert) {
    let progressRequests = 0;
    pretender.get(
      "/admin/plugins/discourse-ai/ai-translations/progress.json",
      () => {
        progressRequests++;
        return response(overview);
      }
    );
    pretender.put("/admin/site_settings/:name", () => response({}));
    // The AI flag is on and locales are saved, but no model is configured, so
    // the server does not consider translations ready.
    this.model.enabled = false;
    this.owner.lookup("service:router").refresh = () => {
      this.set("model", { ...this.model, enabled: false });
    };

    await render(<template><AiTranslations @model={{this.model}} /></template>);
    assert
      .dom("[role='switch']")
      .hasAttribute("aria-checked", "true", "the AI flag is on");

    await form().field("content_localization_enabled").toggle();
    await form().submit();
    await settled();

    assert
      .dom(".ai-translations__overview")
      .doesNotExist("readiness comes from the server, not the form values");
    assert.strictEqual(
      progressRequests,
      0,
      "no progress is requested for a module the server considers off"
    );
    assert
      .dom(".ai-translations__stat-label")
      .doesNotExist(
        "no backfill status is reported while translations are off"
      );
  });

  test("resyncs the switch and progress when a refresh replaces the model", async function (assert) {
    await render(<template><AiTranslations @model={{this.model}} /></template>);
    assert
      .dom("[role='switch']")
      .hasAttribute("aria-checked", "true", "starts enabled");

    this.set("model", {
      ...this.model,
      translation_enabled: false,
      enabled: false,
    });
    await settled();

    assert
      .dom("[role='switch']")
      .hasAttribute("aria-checked", "false", "the toggled state is replaced");
    assert
      .dom(".ai-translations__overview")
      .doesNotExist("the progress panel follows the replaced model");

    this.set("model", {
      ...this.model,
      translation_enabled: true,
      enabled: true,
    });
    await settled();

    assert
      .dom("[role='switch']")
      .hasAttribute(
        "aria-checked",
        "true",
        "the switch follows the model back"
      );
    assert
      .dom(".ai-translations__overview")
      .exists("progress returns with the server's readiness");
  });

  test("labels verbose logging with the translations page copy", async function (assert) {
    await render(<template><AiTranslations @model={{this.model}} /></template>);
    assert
      .form()
      .field("ai_translation_verbose_logs")
      .hasTitle(
        i18n(
          "discourse_ai.translations.settings.ai_translation_verbose_logs.label"
        )
      );
  });
});
