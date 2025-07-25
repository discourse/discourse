# frozen_string_literal: true

class LocalizedAiPersonaSerializer < ApplicationSerializer
  root "ai_persona"

  attributes :id,
             :name,
             :description,
             :enabled,
             :system,
             :priority,
             :tools,
             :system_prompt,
             :allowed_group_ids,
             :temperature,
             :top_p,
             :default_llm_id,
             :user_id,
             :max_context_posts,
             :vision_enabled,
             :vision_max_pixels,
             :rag_chunk_tokens,
             :rag_chunk_overlap_tokens,
             :rag_conversation_chunks,
             :rag_llm_model_id,
             :question_consolidator_llm_id,
             :tool_details,
             :forced_tool_count,
             :allow_chat_channel_mentions,
             :allow_chat_direct_messages,
             :allow_topic_mentions,
             :allow_personal_messages,
             :force_default_llm,
             :response_format,
             :examples,
             :features

  has_one :user, serializer: BasicUserSerializer, embed: :object
  has_many :rag_uploads, serializer: UploadSerializer, embed: :object
  has_one :default_llm, serializer: BasicLlmModelSerializer, embed: :object

  def rag_uploads
    object.uploads
  end

  def name
    object.class_instance.name
  end

  def description
    object.class_instance.description
  end

  def default_llm
    LlmModel.find_by(id: object.default_llm_id)
  end

  def features
    object.features.map do |feature|
      { id: feature.module_id, module_name: feature.module_name, name: feature.name }
    end
  end
end
