# frozen_string_literal: true

class TagSerializer < ApplicationSerializer
  attributes :id, :name, :slug, :topic_count, :staff, :description

  has_many :localizations, serializer: TagLocalizationSerializer, embed: :objects

  def slug
    object.slug_for_url
  end

  def topic_count
    object.public_send(Tag.topic_count_column(scope))
  end

  def staff
    DiscourseTagging.staff_tag_names.include?(name)
  end

  def include_localizations?
    SiteSetting.content_localization_enabled && object.localizations.loaded?
  end
end
