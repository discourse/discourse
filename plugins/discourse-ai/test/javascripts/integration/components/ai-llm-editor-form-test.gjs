import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import formKit from "discourse/tests/helpers/form-kit-helper";
import AiLlmAdapter from "discourse/plugins/discourse-ai/discourse/admin/adapters/ai-llm";
import AiLlm from "discourse/plugins/discourse-ai/discourse/admin/models/ai-llm";
import AiLlmEditorForm from "discourse/plugins/discourse-ai/discourse/components/ai-llm-editor-form";

module("Integration | Component | AiLlmEditorForm", function (hooks) {
  setupRenderingTest(hooks, { stubRouter: true });

  hooks.beforeEach(function () {
    this.owner.register("model:ai-llm", AiLlm);
    this.owner.register("adapter:ai-llm", AiLlmAdapter);
    this.model = this.owner.lookup("service:store").createRecord("ai-llm", {
      id: 7,
      display_name: "Test model",
      name: "gpt-5.4",
      provider: "open_ai",
      provider_params: {},
      tokenizer: "DiscourseAi::Tokenizer::OpenAiTokenizer",
      url: "https://example.com/v1/chat/completions",
      max_prompt_tokens: 32000,
      max_output_tokens: 4000,
      llm_quotas: [],
    });
    this.llms = {
      content: [this.model],
      resultSetMeta: {
        presets: [],
        providers: ["open_ai"],
        provider_params: { open_ai: {} },
        tokenizers: [
          { id: "DiscourseAi::Tokenizer::OpenAiTokenizer", name: "OpenAI" },
        ],
      },
    };
  });

  test("defaults to model reasoning and saves a compression override", async function (assert) {
    pretender.put("/admin/plugins/discourse-ai/ai-llms/7", (request) => {
      const data = JSON.parse(request.requestBody).ai_llm;
      assert.step("save");
      assert.strictEqual(data.compression_thinking_effort, "none");
      return response({ ai_llm: { ...data, id: 7 } });
    });

    await render(
      <template>
        <AiLlmEditorForm @llms={{this.llms}} @model={{this.model}} />
      </template>
    );

    assert.form().field("compression_thinking_effort").hasValue("default");
    assert
      .dom('select[name="compression_thinking_effort"] option')
      .exists({ count: 8 });
    await formKit().field("compression_thinking_effort").select("none");
    await formKit().submit();

    assert.verifySteps(["save"]);
  });

  test("shows a hosted model's saved preference and lets it return to model default", async function (assert) {
    this.model.seeded = true;
    this.model.compression_thinking_effort = "low";
    pretender.put("/admin/plugins/discourse-ai/ai-llms/7", (request) => {
      const data = JSON.parse(request.requestBody).ai_llm;
      assert.step("save");
      assert.strictEqual(data.compression_thinking_effort, "default");
      return response({
        ai_llm: { ...data, id: 7, compression_thinking_effort: null },
      });
    });

    await render(
      <template>
        <AiLlmEditorForm @llms={{this.llms}} @model={{this.model}} />
      </template>
    );

    assert.form().field("compression_thinking_effort").hasValue("low");
    await formKit().field("compression_thinking_effort").select("default");
    await formKit().submit();

    assert.strictEqual(this.model.compression_thinking_effort, null);
    assert.form().field("compression_thinking_effort").hasValue("default");
    assert.verifySteps(["save"]);
  });
});
