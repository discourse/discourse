import { render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import AiDefaultLlmSelector from "discourse/plugins/discourse-ai/discourse/components/ai-default-llm-selector";

module("Integration | Component | ai-default-llm-selector", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    pretender.get("/admin/plugins/discourse-ai/ai-llms.json", () => {
      return response({
        ai_llms: [
          { id: 1, display_name: "GPT-5" },
          { id: 2, display_name: "Claude" },
        ],
      });
    });

    pretender.get("/admin/config/site_settings.json", () => {
      return response({
        site_settings: [
          {
            setting: "ai_default_llm_model",
            value: "",
            default: "",
            type: "enum",
          },
        ],
      });
    });
  });

  test("renders dropdown with None option and models", async function (assert) {
    await render(<template><AiDefaultLlmSelector /></template>);

    const selector = selectKit(".ai-configure-default-llm__setting .combo-box");
    await selector.expand();

    assert.strictEqual(selector.rows().length, 3, "shows None plus two models");
    assert.strictEqual(
      selector.rowByIndex(0).name(),
      "None",
      "first option is None"
    );
    assert.strictEqual(
      selector.rowByIndex(1).name(),
      "GPT-5",
      "second option is GPT-5"
    );
    assert.strictEqual(
      selector.rowByIndex(2).name(),
      "Claude",
      "third option is Claude"
    );
  });

  test("displays None when value is empty", async function (assert) {
    await render(<template><AiDefaultLlmSelector /></template>);

    const selector = selectKit(".ai-configure-default-llm__setting .combo-box");

    assert.strictEqual(
      selector.header().value(),
      "none",
      "None is selected when value is empty"
    );
    assert.strictEqual(selector.header().label(), "None", "displays None text");
  });

  test("displays selected model when value is set", async function (assert) {
    pretender.get("/admin/config/site_settings.json", () => {
      return response({
        site_settings: [
          {
            setting: "ai_default_llm_model",
            value: "1",
            default: "",
            type: "enum",
          },
        ],
      });
    });

    await render(<template><AiDefaultLlmSelector /></template>);

    const selector = selectKit(".ai-configure-default-llm__setting .combo-box");

    assert.strictEqual(selector.header().value(), "1", "model ID is selected");
    assert.strictEqual(
      selector.header().label(),
      "GPT-5",
      "displays model name"
    );
  });

  test("saves empty string when None is selected", async function (assert) {
    let savedValue = null;

    pretender.put("/admin/site_settings/ai_default_llm_model", (request) => {
      const params = new URLSearchParams(request.requestBody);
      savedValue = params.get("ai_default_llm_model");
      return response({});
    });

    await render(<template><AiDefaultLlmSelector /></template>);

    const selector = selectKit(".ai-configure-default-llm__setting .combo-box");
    await selector.expand();
    await selector.selectRowByValue("none");
    await settled();

    assert.strictEqual(
      savedValue,
      "",
      "saves empty string to backend when None selected"
    );
  });

  test("saves model ID when model is selected", async function (assert) {
    let savedValue = null;

    pretender.put("/admin/site_settings/ai_default_llm_model", (request) => {
      const params = new URLSearchParams(request.requestBody);
      savedValue = params.get("ai_default_llm_model");
      return response({});
    });

    await render(<template><AiDefaultLlmSelector /></template>);

    const selector = selectKit(".ai-configure-default-llm__setting .combo-box");
    await selector.expand();
    await selector.selectRowByValue("1");
    await settled();

    assert.strictEqual(savedValue, "1", "saves model ID to backend");
  });
});
