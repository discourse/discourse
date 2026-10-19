module Holidays
  module Definition
    module Repository
      class Cache
        def initialize
          reset!
        end

        def cache_between(start_date, end_date, cache_data, options)
          raise ArgumentError unless cache_data
          raise ArgumentError unless start_date && end_date

          @cache_range[options] = start_date..end_date
          @cache[options] = cache_data.group_by { |holiday| holiday[:date] }
        end

        def find(start_date, end_date, options)
          return nil unless in_cache_range?(start_date, end_date, options)

          if start_date == end_date
            @cache[options].fetch(start_date, [])
          else
            @cache[options].select do |date, holidays|
              date >= start_date && date <= end_date
            end.flat_map { |date, holidays| holidays }
          end
        end

        def reset!
          @cache = {}
          @cache_range = {}
        end

        private

        def in_cache_range?(start_date, end_date, options)
          range = @cache_range[options]
          if range
            range.begin <= start_date && range.end >= end_date
          else
            false
          end
        end
      end
    end
  end
end
