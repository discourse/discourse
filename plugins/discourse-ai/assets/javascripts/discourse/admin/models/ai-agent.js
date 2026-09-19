import { ajax } from "discourse/lib/ajax";
import RestModel from "discourse/models/rest";
import { toPlainObject } from "../../lib/utilities";

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
  "thinking_effort",
  "user_id",
  "default_llm_id",
  "force_default_llm",
  "user",
  "vision_enabled",
  "vision_max_pixels",
  "rag_uploads",
  "rag_document_sources",
  "rag_document_sources_attributes",
  "rag_chunk_tokens",
  "rag_chunk_overlap_tokens",
  "rag_conversation_chunks",
  "rag_llm_model_id",
  "show_thinking",
  "forced_tool_count",
  "allow_personal_messages",
  "allow_topic_mentions",
  "allow_chat_channel_mentions",
  "allow_chat_direct_messages",
  "mcp_server_ids",
  "mcp_server_tool_names",
  "subagent_ids",
  "max_turn_tokens",

  "compression_threshold",
  "require_approval",
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
  "vision_enabled",
  "vision_max_pixels",
  "rag_uploads",
  "rag_document_sources",
  "rag_document_sources_attributes",
  "rag_chunk_tokens",
  "rag_chunk_overlap_tokens",
  "rag_conversation_chunks",
  "rag_llm_model_id",
  "show_thinking",
  "thinking_effort",
  "allow_personal_messages",
  "allow_topic_mentions",
  "allow_chat_channel_mentions",
  "allow_chat_direct_messages",
  "mcp_server_ids",
  "mcp_server_tool_names",
  "max_turn_tokens",

  "compression_threshold",
  "require_approval",
];

export default class AiAgent extends RestModel {
  async createUser() {
    const result = await ajax(
      `/admin/plugins/discourse-ai/ai-agents/${this.id}/create-user.json`,
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
    delete attrs.rag_document_sources;

    return attrs;
  }

  createProperties() {
    const attrs = this.getProperties(CREATE_ATTRIBUTES);
    delete attrs.rag_document_sources;
    return attrs;
  }

  fromPOJO(data) {
    const dataClone = toPlainObject(data);
    const configuredSources = dataClone.rag_document_sources || [];
    const configuredSourceIds = new Set(
      configuredSources.map((source) => source.id).filter(Boolean)
    );

    dataClone.rag_document_sources_attributes = configuredSources.map(
      (source) => ({
        id: source.id,
        url: source.url,
        refresh_interval_hours: source.refresh_interval_hours,
      })
    );

    (this.rag_document_sources || []).forEach((source) => {
      if (source.id && !configuredSourceIds.has(source.id)) {
        dataClone.rag_document_sources_attributes.push({
          id: source.id,
          _destroy: true,
        });
      }
    });
    delete dataClone.rag_document_sources;

    const agent = AiAgent.create(dataClone);
    agent.tools = this.flattenedToolStructure(dataClone);

    return agent;
  }

  toPOJO() {
    const attrs = this.getProperties(CREATE_ATTRIBUTES);
    this.populateTools(attrs);
    attrs.mcp_server_ids = attrs.mcp_server_ids || [];
    attrs.mcp_server_tool_names = attrs.mcp_server_tool_names || {};
    attrs.subagent_ids = attrs.subagent_ids || [];
    attrs.forced_tool_count = this.forced_tool_count || -1;
    attrs.thinking_effort = attrs.thinking_effort || "default";
    attrs.response_format = attrs.response_format || [];
    attrs.examples = attrs.examples || [];
    attrs.rag_document_sources = attrs.rag_document_sources || [];
    // FormKit uses Immer proxies which cause issues when passed to upload handlers.
    // Convert to plain objects to ensure compatibility.
    if (attrs.rag_uploads?.length > 0) {
      attrs.rag_uploads = toPlainObject(attrs.rag_uploads);
    }

    return attrs;
  }
}
