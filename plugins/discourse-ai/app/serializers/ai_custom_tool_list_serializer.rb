# frozen_string_literal: true

class AiCustomToolListSerializer < ApplicationSerializer
  attributes :meta

  has_many :ai_tools, serializer: AiCustomToolSerializer, embed: :objects

  def meta
    {
      presets: AiTool.presets,
      llms: DiscourseAi::Configuration::LlmEnumerator.values_for_serialization,
      ai_secrets: AiSecret.order(:name).pluck(:id, :name).map { |id, name| { id: id, name: name } },
      settings: {
        rag_images_enabled: SiteSetting.ai_rag_images_enabled,
      },
    }
  end

  def ai_tools
    object[:ai_tools]
  end
end
