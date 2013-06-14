class Search

  class GroupedSearchResults
    attr_reader :topic_count, :type_filter

    def initialize(type_filter)
      @type_filter = type_filter
      @by_type = {}
      @topic_count = 0
    end

    def topic_ids
      topic_results = @by_type[:topic]
      return Set.new if topic_results.blank?
      return topic_results.result_ids
    end

    def as_json
      @by_type.values.map do |grouped_result|
        grouped_result.as_json
      end
    end

    def add_result(result)
      grouped_result = @by_type[result.type] || (@by_type[result.type] = SearchResultType.new(result.type))

      # Limit our results if there is no filter
      if @type_filter.present? or (grouped_result.size < Search.per_facet)
        @topic_count += 1 if (result.type == :topic)

        grouped_result.add(result)
      else
        grouped_result.more = true
      end
    end

  end

end