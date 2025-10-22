# frozen_string_literal: true

class TopicListSerializer < ApplicationSerializer
  attributes :can_create_topic,
             :more_topics_url,
             :for_period,
             :per_page,
             :top_tags,
             :tags,
             :shared_drafts,
             :filter_option_info

  has_many :topics, serializer: TopicListItemSerializer, embed: :objects
  has_many :shared_drafts, serializer: TopicListItemSerializer, embed: :objects
  has_many :tags, serializer: TagSerializer, embed: :objects
  has_many :categories, serializer: CategoryBadgeSerializer, embed: :objects

  def initialize(object, options = {})
    super
    options[:filter] = object.filter
  end

  def can_create_topic
    scope.can_create?(Topic)
  end

  def include_shared_drafts?
    object.shared_drafts.present?
  end

  def include_filter_option_info?
    object.filter_option_info.present?
  end

  def include_for_period?
    for_period.present?
  end

  def include_more_topics_url?
    object.more_topics_url.present? && (object.topics.size == object.per_page)
  end

  def include_top_tags?
    Tag.include_tags?
  end

  def include_tags?
    SiteSetting.tagging_enabled && object.tags.present?
  end

  def include_categories?
    scope.can_lazy_load_categories?
  end
end
