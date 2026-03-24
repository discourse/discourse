import { module, test } from "qunit";
import AiAgent from "discourse/plugins/discourse-ai/discourse/admin/models/ai-agent";

module("Discourse AI | Unit | Model | ai-agent", function () {
  test("toPOJO", function (assert) {
    const properties = {
      tools: [
        ["ToolName", { option1: "value1", option2: "value2" }, false],
        "ToolName2",
        "ToolName3",
      ],
    };

    const aiAgentPOJO = AiAgent.create(properties).toPOJO();

    assert.deepEqual(aiAgentPOJO.tools, ["ToolName", "ToolName2", "ToolName3"]);
    assert.strictEqual(aiAgentPOJO.toolOptions["ToolName"].option1, "value1");
    assert.strictEqual(aiAgentPOJO.toolOptions["ToolName"].option2, "value2");
  });

  test("fromPOJO", function (assert) {
    const properties = {
      id: 1,
      name: "Test",
      tools: [["ToolName", { option1: "value1" }, false]],
      allowed_group_ids: [12],
      system: false,
      enabled: true,
      system_prompt: "System Prompt",
      priority: false,
      description: "Description",
      top_p: 0.8,
      temperature: 0.7,
      default_llm_id: 1,
      force_default_llm: false,
      user: null,
      user_id: null,
      max_context_posts: 5,
      vision_enabled: true,
      vision_max_pixels: 100,
      rag_uploads: [],
      rag_chunk_tokens: 374,
      rag_chunk_overlap_tokens: 10,
      rag_conversation_chunks: 10,
      rag_llm_model_id: 1,
      show_thinking: true,
      forced_tool_count: -1,
      allow_personal_messages: true,
      allow_topic_mentions: true,
      allow_chat_channel_mentions: true,
      allow_chat_direct_messages: true,
    };
    const updatedValue = "updated";

    const aiAgent = AiAgent.create({ ...properties });

    const agentPOJO = aiAgent.toPOJO();

    agentPOJO.toolOptions["ToolName"].option1 = updatedValue;
    agentPOJO.forcedTools = "ToolName";

    const updatedAgent = aiAgent.fromPOJO(agentPOJO);

    assert.deepEqual(updatedAgent.tools, [
      ["ToolName", { option1: updatedValue }, true],
    ]);
  });
});
