# frozen_string_literal: true

class LlmQuotaSerializer < ApplicationSerializer
  attributes :id, :group_id, :llm_model_id, :max_tokens, :max_usages, :duration_seconds, :group_name

  def group_name
    object.group.name
  end
end
