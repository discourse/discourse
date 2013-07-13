require_dependency 'topic_list'

class SuggestedTopicsBuilder

  attr_reader :excluded_topic_ids
  attr_reader :results

  def initialize(topic)
    @excluded_topic_ids = [topic.id]
    @results = []
  end

  def add_results(results)

    return if results.blank?

    # Only add results if we don't have those topic ids already
    results = results.where('topics.id NOT IN (?)', @excluded_topic_ids)
                     .where(closed: false, archived: false, visible: true)

    return if results.blank?

    # Keep track of the ids we've added
    @excluded_topic_ids << results.map {|r| r.id}
    @excluded_topic_ids.flatten!

    @results << results
    @results.flatten!
  end

  def results_left
    SiteSetting.suggested_topics - @results.size
  end

  def full?
    results_left == 0
  end

  def size
    @results.size
  end

end