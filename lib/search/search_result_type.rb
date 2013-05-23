class Search

  class SearchResultType
    attr_accessor :more, :results

    def initialize(type)
      @type = type
      @results = []
      @more = false
    end

    def size
      @results.size
    end

    def add(result)
      @results << result
    end

    def as_json
      { type: @type.to_s,
        name: I18n.t("search.types.#{@type.to_s}"),
        more: @more,
        results: @results.map(&:as_json) }
    end
  end

end