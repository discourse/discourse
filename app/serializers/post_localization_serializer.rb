# frozen_string_literal: true

class PostLocalizationSerializer < ApplicationSerializer
  attributes :id, :post_id, :post_version, :locale, :raw, :topic_localization

  def topic_localization
    TopicLocalizationSerializer.new(object.topic_localization, root: false).as_json
  end

  def include_topic_localization?
    object.respond_to?(:topic_localization) && object.topic_localization.present?
  end
end
