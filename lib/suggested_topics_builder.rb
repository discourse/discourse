require_dependency 'topic_list'

class SuggestedTopicsBuilder

  attr_reader :excluded_topic_ids

  def initialize(topic)
    @excluded_topic_ids = [topic.id]
    @category_id = topic.category_id
    @results = []
  end


  def add_results(results, priority=:low)

    # WARNING .blank? will execute an Active Record query
    return unless results

    # Only add results if we don't have those topic ids already
    results = results.where('topics.id NOT IN (?)', @excluded_topic_ids)
                     .where(closed: false, archived: false, visible: true)
                     .to_a

    unless results.empty?
      # Keep track of the ids we've added
      @excluded_topic_ids.concat results.map {|r| r.id}
      splice_results(results,priority)
    end
  end

  def splice_results(results, priority)
    if  @category_id &&
        priority == :high &&
        non_category_index = @results.index{|r| r.category_id != @category_id}

      category_results, non_category_results = results.partition{|r| r.category_id == @category_id}

      @results.insert non_category_index, *category_results
      @results.concat non_category_results
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
    SiteSetting.suggested_topics - @results.count{|r| r.category_id == @category_id}
  end

  def category_full?
    if @category_id

    else
      full?
    end
  end

  def size
    @results.size
  end

end
