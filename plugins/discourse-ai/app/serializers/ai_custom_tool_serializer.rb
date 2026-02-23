# frozen_string_literal: true

class AiCustomToolSerializer < ApplicationSerializer
  attributes :id,
             :name,
             :tool_name,
             :description,
             :summary,
             :parameters,
             :script,
             :secret_contracts,
             :secret_bindings,
             :rag_chunk_tokens,
             :rag_chunk_overlap_tokens,
             :rag_llm_model_id,
             :created_by_id,
             :created_at,
             :updated_at

  self.root = "ai_tool"

  has_many :rag_uploads, serializer: UploadSerializer, embed: :object

  def rag_uploads
    object.uploads
  end

  def include_secret_bindings?
    return true if scope.blank? || !scope.is_a?(Hash)

    scope[:include_secret_bindings] != false
  end

  def secret_bindings
    object.secret_bindings.map { |binding| binding.slice(:alias, :ai_secret_id) }
  end
end
