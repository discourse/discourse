# frozen_string_literal: true

module Plugin
  class FilterManager

    def initialize
      @map = {}
    end

    def register(name, &blk)
      raise ArgumentError unless blk && blk.arity == 2
      filters = @map[name] ||= []
      filters << blk
    end

    def apply(name, context, result)
      if filters = @map[name]
        filters.each do |blk|
          result = blk.call(context, result)
        end
      end
      result
    end
  end
end
