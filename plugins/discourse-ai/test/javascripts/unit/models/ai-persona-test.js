/* eslint-disable qunit/no-assert-equal */
/* eslint-disable qunit/no-loose-assertions */
import { module, test } from "qunit";
import AiPersona from "discourse/plugins/discourse-ai/discourse/admin/models/ai-persona";

module("Discourse AI | Unit | Model | ai-persona", function () {
  test("toPOJO", function (assert) {
    const properties = {
      tools: [
        ["ToolName", { option1: "value1", option2: "value2" }, false],
        "ToolName2",
        "ToolName3",
      ],
    };

    const aiPersonaPOJO = AiPersona.create(properties).toPOJO();

    assert.deepEqual(aiPersonaPOJO.tools, [
      "ToolName",
      "ToolName2",
      "ToolName3",
    ]);
    assert.equal(aiPersonaPOJO.toolOptions["ToolName"].option1, "value1");
    assert.equal(aiPersonaPOJO.toolOptions["ToolName"].option2, "value2");
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
      question_consolidator_llm_id: 2,
      allow_chat: false,
      tool_details: true,
      forced_tool_count: -1,
      allow_personal_messages: true,
      allow_topic_mentions: true,
      allow_chat_channel_mentions: true,
      allow_chat_direct_messages: true,
    };
    const updatedValue = "updated";

    const aiPersona = AiPersona.create({ ...properties });

    const personaPOJO = aiPersona.toPOJO();

    personaPOJO.toolOptions["ToolName"].option1 = updatedValue;
    personaPOJO.forcedTools = "ToolName";

    const updatedPersona = aiPersona.fromPOJO(personaPOJO);

    assert.deepEqual(updatedPersona.tools, [
      ["ToolName", { option1: updatedValue }, true],
    ]);
  });
});
