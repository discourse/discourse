require 'holidays/definition/entity/test'

module Holidays
  module Definition
    module Parser
      class Test
        def initialize(validator)
          @validator = validator
        end

        def call(tests)
          return [] if tests.nil?

          validate!(tests)

          tests.map do |t|
            given = t["given"]
            expect = t["expect"]

            Entity::Test.new(
              dates: parse_dates(given["date"]),
              regions: parse_regions(given["regions"]),
              options: parse_options(given["options"]),
              name: expect["name"],
              holiday?: is_holiday?(expect["holiday"]),
            )
          end
        end

        private

        def validate!(tests)
          raise ArgumentError unless tests.all? do |t|
            dates = t["given"]["date"]
            unless dates.is_a?(Array)
              dates = [ dates ]
            end

            @validator.valid?(
              {
                :dates => dates,
                :regions => t["given"]["regions"],
                :options => t["given"]["options"],
                :name => t["expect"]["name"],
                :holiday => t["expect"]["holiday"],
              }
            )
          end
        end

        def parse_dates(dates)
          unless dates.is_a?(Array)
            dates = [ dates ]
          end

          dates.map do |d|
            DateTime.parse(d)
          end
        end

        def parse_regions(regions)
          regions.map do |r|
            r.to_sym
          end
        end

        def parse_options(options)
          if options
            if options.is_a?(Array)
              options.map do |o|
                o.to_sym
              end
            else
              [ options.to_sym ]
            end
          end
        end

        # If flag is not present then default to 'true'
        def is_holiday?(flag)
          flag.nil? ? true : !!flag
        end
      end
    end
  end
end
