module Holidays
  module Finder
    module Context
      class Between
        def initialize(definition_search, dates_driver_builder, options_parser)
          @definition_search = definition_search
          @dates_driver_builder = dates_driver_builder
          @options_parser = options_parser
        end

        def call(start_date, end_date, options)
          validate!(start_date, end_date)

          regions, observed, informal = @options_parser.call(options)
          dates_driver = @dates_driver_builder.call(start_date, end_date)

          #FIXME Why are we calling the options_parser to convert the observed/informal
          # symbols to bool and then...converting them back? O_o
          opts = gather_options(observed, informal)

          @definition_search
            .call(dates_driver, regions, opts)
            .select { |holiday| holiday[:date].between?(start_date, end_date) }
            .sort_by { |a| a[:date] }
        end

        private

        def validate!(start_date, end_date)
          raise ArgumentError unless start_date
          raise ArgumentError unless end_date
        end

        def gather_options(observed, informal)
          opts = []

          opts << :observed if observed
          opts << :informal if informal

          opts
        end
      end
    end
  end
end
