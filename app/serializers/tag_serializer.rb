# frozen_string_literal: true

class TagSerializer < ApplicationSerializer
  include LocalizedTagMixin

  attributes :id, :slug, :topic_count, :staff, :description_cooked

  has_many :localizations, serializer: TagLocalizationSerializer, embed: :objects

  def slug
    object.slug_for_url
  end

  def description_cooked
    object.display_description_cooked(scope)
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
