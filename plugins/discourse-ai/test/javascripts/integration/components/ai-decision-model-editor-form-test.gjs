import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import formKit from "discourse/tests/helpers/form-kit-helper";
import { i18n } from "discourse-i18n";
import AiDecisionModelEditorForm from "discourse/plugins/discourse-ai/discourse/components/ai-decision-model-editor-form";

module("Integration | Component | AiDecisionModelEditorForm", function (hooks) {
  setupRenderingTest(hooks, { stubRouter: true });

  hooks.beforeEach(function () {
    const router = this.owner.lookup("service:router");
    router.replaceWith = async () => {};
    router.transitionTo = async () => {};

    this.decisionModels = {
      resultSetMeta: {
        providers: ["system_one", "typesafe", "open_ai"],
        presets: [],
        ai_secrets: [],
        custom_header_limits: {
          count: 20,
          name_length: 128,
          value_length: 4000,
        },
      },
    };
    this.savedPayload = null;
    this.model = {
      id: 1,
      isNew: false,
      display_name: "Decisions",
      name: "test-model",
      provider: "system_one",
      url: "https://example.com/decisions",
      custom_headers: [{ name: "X-Image-Input", value: "true" }],
      save: async (payload) => {
        this.savedPayload = payload;
      },
    };
  });

  test("limits header rows using the server-provided maximum", async function (assert) {
    this.decisionModels.resultSetMeta.custom_header_limits.count = 2;
    await render(
      <template>
        <AiDecisionModelEditorForm
          @decisionModels={{this.decisionModels}}
          @model={{this.model}}
        />
      </template>
    );
    assert
      .dom(".ai-decision-model-editor__add-header")
      .isEnabled("allows another header below the limit");
    await click(".ai-decision-model-editor__add-header");
    assert
      .dom(".ai-decision-model-editor__add-header")
      .isDisabled("prevents adding more than the configured limit");
    await click(".ai-decision-model-editor__remove-header");
    assert
      .dom(".ai-decision-model-editor__add-header")
      .isEnabled("allows adding a header again after removing a row");
  });

  test("edits, adds and removes custom headers", async function (assert) {
    await render(
      <template>
        <AiDecisionModelEditorForm
          @decisionModels={{this.decisionModels}}
          @model={{this.model}}
        />
      </template>
    );

    assert
      .dom(".ai-decision-model-editor__remove-header")
      .hasAttribute(
        "title",
        i18n("discourse_ai.decision_models.custom_headers.remove"),
        "the icon-only remove button has an accessible name"
      );
    assert
      .form()
      .field("custom_headers.0.name")
      .hasValue("X-Image-Input", "loads the saved header name");
    assert
      .form()
      .field("custom_headers.0.value")
      .hasValue("true", "loads the saved header value");
    await formKit().field("custom_headers.0.value").fillIn("false");
    await click(".ai-decision-model-editor__add-header");
    await formKit().field("custom_headers.1.name").fillIn("X-Mode");
    await formKit().field("custom_headers.1.value").fillIn("images");
    await formKit().submit();
    assert.deepEqual(
      this.savedPayload.custom_headers,
      [
        { name: "X-Image-Input", value: "false" },
        { name: "X-Mode", value: "images" },
      ],
      "submits all header rows"
    );
    assert.strictEqual(
      this.model.custom_headers[0].value,
      "true",
      "edits do not mutate the model before saving"
    );

    await click(".ai-decision-model-editor__remove-header");
    await click(".ai-decision-model-editor__remove-header");
    assert
      .dom(".ai-decision-model-editor .form-kit__collection")
      .doesNotExist("the empty header collection leaves no layout wrapper");
    assert
      .dom(".ai-decision-model-editor__add-header")
      .isEnabled("the empty state still offers adding a header");
    await formKit().submit();
    assert.deepEqual(
      this.savedPayload.custom_headers,
      [],
      "submits an empty array to clear headers"
    );
  });

  test("image presets populate headers and text presets clear them", async function (assert) {
    this.model.isNew = true;
    this.decisionModels.content = [];
    const imageHeader = { name: "TypeSafe-Danger-Zone-Images", value: "true" };
    const textPreset = {
      preset_id: "jev-latest",
      display_name: "TypeSafe Jev",
      name: "jev-latest",
      provider: "typesafe",
      url: "https://api.typesafe.ai/v1/systemone",
      vision_enabled: false,
    };
    this.decisionModels.resultSetMeta.presets = [
      textPreset,
      {
        ...textPreset,
        preset_id: "jev-latest-vision",
        display_name: "TypeSafe Jev with images (experimental)",
        vision_enabled: true,
        custom_headers: [imageHeader],
      },
    ];

    await render(
      <template>
        <AiDecisionModelEditorForm
          @decisionModels={{this.decisionModels}}
          @model={{this.model}}
        />
      </template>
    );
    await formKit().field("preset").select("jev-latest-vision");
    assert
      .form()
      .field("provider")
      .hasValue("typesafe", "uses the dedicated TypeSafe endpoint");
    assert.form().field("vision_enabled").hasValue(true, "enables image input");
    assert
      .form()
      .field("custom_headers.0.name")
      .hasValue(imageHeader.name, "populates the image header");
    assert
      .form()
      .field("custom_headers.0.value")
      .hasValue(imageHeader.value, "populates the header value");
    await formKit().submit();
    assert.deepEqual(
      this.savedPayload.custom_headers,
      [imageHeader],
      "saves the image opt-in header"
    );

    await formKit().field("custom_headers.0.value").fillIn("false");
    assert.strictEqual(
      imageHeader.value,
      "true",
      "editing the draft leaves preset metadata unchanged"
    );
    await formKit().field("preset").select("jev-latest");
    assert
      .form()
      .field("vision_enabled")
      .hasValue(false, "disables image input for the text preset");
    await formKit().submit();
    assert.deepEqual(
      this.savedPayload.custom_headers,
      [],
      "clears the opt-in header for the text preset"
    );
  });

  test("selecting a preset clears headers unsupported by its provider", async function (assert) {
    this.model.isNew = true;
    this.decisionModels.content = [];
    this.decisionModels.resultSetMeta.presets = [
      {
        preset_id: "open-ai-test",
        display_name: "OpenAI test",
        name: "test-model",
        provider: "open_ai",
        url: "https://example.com/decisions",
        vision_enabled: true,
      },
    ];
    let testedPayload;
    this.model.testConfig = async (payload) => {
      testedPayload = payload;
      return { success: true, probability: 0.99 };
    };

    await render(
      <template>
        <AiDecisionModelEditorForm
          @decisionModels={{this.decisionModels}}
          @model={{this.model}}
        />
      </template>
    );
    await formKit().field("preset").select("open-ai-test");
    assert
      .dom(".ai-decision-model-editor__add-header")
      .doesNotExist("hides unsupported headers after selecting the preset");
    await click(".ai-decision-model-editor__test-btn");
    assert.deepEqual(
      testedPayload.custom_headers,
      [],
      "tests the preset without stale headers"
    );
    await formKit().submit();
    assert.deepEqual(
      this.savedPayload.custom_headers,
      [],
      "saves the preset without stale headers"
    );
  });

  test("switching between System One and TypeSafe preserves custom headers", async function (assert) {
    await render(
      <template>
        <AiDecisionModelEditorForm
          @decisionModels={{this.decisionModels}}
          @model={{this.model}}
        />
      </template>
    );

    for (const provider of ["typesafe", "system_one"]) {
      await formKit().field("provider").select(provider);
      assert
        .form()
        .field("custom_headers.0.name")
        .hasValue(
          "X-Image-Input",
          `preserves headers when switching to ${provider}`
        );
      await formKit().submit();
      assert.strictEqual(
        this.savedPayload.provider,
        provider,
        "submits the selected provider"
      );
      assert.deepEqual(
        this.savedPayload.custom_headers,
        [{ name: "X-Image-Input", value: "true" }],
        "submits the preserved headers"
      );
    }
  });

  test("switching providers clears unsupported custom headers", async function (assert) {
    this.model.provider = "typesafe";
    await render(
      <template>
        <AiDecisionModelEditorForm
          @decisionModels={{this.decisionModels}}
          @model={{this.model}}
        />
      </template>
    );
    await formKit().field("provider").select("open_ai");
    assert
      .dom(".ai-decision-model-editor__add-header")
      .doesNotExist("hides custom headers for other providers");
    await formKit().submit();
    assert.deepEqual(
      this.savedPayload.custom_headers,
      [],
      "does not submit System One headers to another provider"
    );
    await formKit().field("provider").select("system_one");
    assert
      .dom(".ai-decision-model-editor__add-header")
      .exists("shows custom headers for System One");
    assert.false(
      formKit().hasField("custom_headers.0.name"),
      "does not restore stale headers"
    );
  });
});
