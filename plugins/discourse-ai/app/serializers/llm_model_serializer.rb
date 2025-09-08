# frozen_string_literal: true

class LlmModelSerializer < ApplicationSerializer
  # TODO: we probably should rename the table LlmModel to AiLlm
  # it is consistent with AiPersona and AiTool
  # LLM model is a bit confusing given that large langauge model model is a confusing
  # name
  root "ai_llm"
  attributes :id,
             :display_name,
             :name,
             :provider,
             :max_prompt_tokens,
             :max_output_tokens,
             :tokenizer,
             :api_key,
             :url,
             :enabled_chat_bot,
             :provider_params,
             :vision_enabled,
             :input_cost,
             :output_cost,
             :cached_input_cost,
             :used_by

  has_one :user, serializer: BasicUserSerializer, embed: :object
  has_many :llm_quotas, serializer: LlmQuotaSerializer, embed: :objects

  def used_by
    llm_usage =
      (
        if (scope && scope[:llm_usage])
          scope[:llm_usage]
        else
          DiscourseAi::Configuration::LlmEnumerator.global_usage
        end
      )

    llm_usage[object.id]
  end

  def api_key
    object.seeded? ? "********" : object.api_key
  end

  def url
    object.seeded? ? "********" : object.url
  end

  def provider
    object.seeded? ? "CDCK" : object.provider
  end
end
