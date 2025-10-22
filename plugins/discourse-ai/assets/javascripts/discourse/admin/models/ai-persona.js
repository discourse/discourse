import { ajax } from "discourse/lib/ajax";
import RestModel from "discourse/models/rest";

const CREATE_ATTRIBUTES = [
  "id",
  "name",
  "description",
  "tools",
  "system_prompt",
  "allowed_group_ids",
  "enabled",
  "system",
  "priority",
  "top_p",
  "temperature",
  "user_id",
  "default_llm_id",
  "force_default_llm",
  "user",
  "max_context_posts",
  "vision_enabled",
  "vision_max_pixels",
  "rag_uploads",
  "rag_chunk_tokens",
  "rag_chunk_overlap_tokens",
  "rag_conversation_chunks",
  "rag_llm_model_id",
  "question_consolidator_llm_id",
  "allow_chat",
  "tool_details",
  "forced_tool_count",
  "allow_personal_messages",
  "allow_topic_mentions",
  "allow_chat_channel_mentions",
  "allow_chat_direct_messages",
  "response_format",
  "examples",
];

const SYSTEM_ATTRIBUTES = [
  "id",
  "allowed_group_ids",
  "enabled",
  "system",
  "priority",
  "tools",
  "user_id",
  "default_llm_id",
  "force_default_llm",
  "user",
  "max_context_posts",
  "vision_enabled",
  "vision_max_pixels",
  "rag_uploads",
  "rag_chunk_tokens",
  "rag_chunk_overlap_tokens",
  "rag_conversation_chunks",
  "rag_llm_model_id",
  "question_consolidator_llm_id",
  "tool_details",
  "allow_personal_messages",
  "allow_topic_mentions",
  "allow_chat_channel_mentions",
  "allow_chat_direct_messages",
];

export default class AiPersona extends RestModel {
  async createUser() {
    const result = await ajax(
      `/admin/plugins/discourse-ai/ai-personas/${this.id}/create-user.json`,
      {
        type: "POST",
      }
    );
    this.user = result.user;
    this.user_id = this.user.id;
    return this.user;
  }

  flattenedToolStructure(data) {
    return (data.tools || []).map((tName) => {
      return [
        tName,
        data.toolOptions[tName] || {},
        data.forcedTools.includes(tName),
      ];
    });
  }

  // this code is here to convert the wire schema to easier to work with object
  // on the wire we pass in/out tools as an Array.
  // [[ToolName, {option1: value, option2: value}, force], ToolName2, ToolName3]
  // We split it into tools, options and a list of forced ones.
  populateTools(attrs) {
    const forcedTools = [];
    const toolOptions = {};

    const flatTools = attrs.tools?.map((tool) => {
      if (typeof tool === "string") {
        return tool;
      } else {
        let [toolId, options, force] = tool;
        const mappedOptions = {};

        for (const optionId in options) {
          if (!options.hasOwnProperty(optionId)) {
            continue;
          }

          mappedOptions[optionId] = options[optionId];
        }

        if (Object.keys(mappedOptions).length > 0) {
          toolOptions[toolId] = mappedOptions;
        }

        if (force) {
          forcedTools.push(toolId);
        }

        return toolId;
      }
    });

    attrs.tools = flatTools;
    attrs.forcedTools = forcedTools;
    attrs.toolOptions = toolOptions;
  }

  updateProperties() {
    const attrs = this.system
      ? this.getProperties(SYSTEM_ATTRIBUTES)
      : this.getProperties(CREATE_ATTRIBUTES);
    attrs.id = this.id;

    return attrs;
  }

  createProperties() {
    return this.getProperties(CREATE_ATTRIBUTES);
  }

  fromPOJO(data) {
    const dataClone = JSON.parse(JSON.stringify(data));

    const persona = AiPersona.create(dataClone);
    persona.tools = this.flattenedToolStructure(dataClone);

    return persona;
  }

  toPOJO() {
    const attrs = this.getProperties(CREATE_ATTRIBUTES);
    this.populateTools(attrs);
    attrs.forced_tool_count = this.forced_tool_count || -1;
    attrs.response_format = attrs.response_format || [];
    attrs.examples = attrs.examples || [];

    return attrs;
  }
}
