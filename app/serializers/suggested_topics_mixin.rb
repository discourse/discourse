module SuggestedTopicsMixin
  def self.included(klass)
    klass.attributes :suggested_topics
  end

  def include_suggested_topics?
    object.next_page.nil? && object.suggested_topics&.topics.present?
  end

  def suggested_topics
    object.suggested_topics.topics.map do |t|
      SuggestedTopicSerializer.new(t, scope: scope, root: false)
    end
  end
end
