require_dependency 'topic_list'

class SuggestedTopicsBuilder

  attr_reader :excluded_topic_ids

  def initialize(topic)
    @excluded_topic_ids = [topic.id]
    @category_id = topic.category_id
    @category_topic_ids = Category.topic_ids
    @results = []
  end

  def add_results(results, priority = :low)

    # WARNING .blank? will execute an Active Record query
    return unless results

    # Only add results if we don't have those topic ids already
    results = results.where('topics.id NOT IN (?)', @excluded_topic_ids)
      .where(visible: true)

    # If limit suggested to category is enabled, restrict to that category
    if @category_id && SiteSetting.limit_suggested_to_category?
      results = results.where(category_id: @category_id)
    end

    results = results.to_a
    results.reject! { |topic| @category_topic_ids.include?(topic.id) }

    unless results.empty?
      # Keep track of the ids we've added
      @excluded_topic_ids.concat results.map { |r| r.id }
      splice_results(results, priority)
    end
  end

  def splice_results(results, priority)
    if  @category_id && priority == :high

      # Topics from category @category_id need to be first in the list, all others after.

      other_category_index = @results.index { |r| r.category_id != @category_id }
      category_results, other_category_results = results.partition { |r| r.category_id == @category_id }

      if other_category_index
        @results.insert other_category_index, *category_results
      else
        @results.concat category_results
      end
      @results.concat other_category_results
    else
      @results.concat results
    end
  end

  def results
    @results.first(SiteSetting.suggested_topics)
  end

  def results_left
    SiteSetting.suggested_topics - @results.size
  end

  def full?
    results_left <= 0
  end

  def category_results_left
    SiteSetting.suggested_topics - @results.count { |r| r.category_id == @category_id }
  end

  def size
    @results.size
  end

end
