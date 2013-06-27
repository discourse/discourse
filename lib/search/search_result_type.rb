class Search

  class SearchResultType
    attr_accessor :more, :results, :result_ids

    def initialize(type)
      @type = type
      @results = []
      @result_ids = Set.new
      @more = false
    end

    def size
      @results.size
    end

    def add(result)
      return if @result_ids.include?(result.id)
      @results << result
      @result_ids << result.id
    end

    def as_json
      { type: @type.to_s,
        name: I18n.t("search.types.#{@type.to_s}"),
        more: @more,
        results: @results.map(&:as_json) }
    end
  end

end