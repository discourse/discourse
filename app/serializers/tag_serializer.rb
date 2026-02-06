# frozen_string_literal: true

class TagSerializer < ApplicationSerializer
  attributes :id, :name, :slug, :topic_count, :staff, :description

  has_many :localizations, serializer: TagLocalizationSerializer, embed: :objects

  def name
    translated =
      (object.get_localization&.name if ContentLocalization.show_translated_tag?(object, scope))
    translated || object.name
  end

  def description
    translated =
      if ContentLocalization.show_translated_tag?(object, scope)
        object.get_localization&.description
      end
    translated || object.description
  end

  def topic_count
    object.public_send(Tag.topic_count_column(scope))
  end

  def staff
    DiscourseTagging.staff_tag_names.include?(object.name)
  end

  def include_localizations?
    SiteSetting.content_localization_enabled && object.localizations.loaded?
  end
end
