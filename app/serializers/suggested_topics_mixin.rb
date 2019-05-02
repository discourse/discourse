# frozen_string_literal: true

module SuggestedTopicsMixin
  def self.included(klass)
    klass.attributes :related_messages
    klass.attributes :suggested_topics
  end

  def include_related_messages?
    object.next_page.nil? && object.related_messages&.topics.present?
  end

  def include_suggested_topics?
    object.next_page.nil? && object.suggested_topics&.topics.present?
  end

  def related_messages
    object.related_messages.topics.map do |t|
      SuggestedTopicSerializer.new(t, scope: scope, root: false)
    end
  end

  def suggested_topics
    object.suggested_topics.topics.map do |t|
      SuggestedTopicSerializer.new(t, scope: scope, root: false)
    end
  end
end
