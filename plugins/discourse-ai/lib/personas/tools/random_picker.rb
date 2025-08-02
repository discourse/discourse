# frozen_string_literal: true

module DiscourseAi
  module Personas
    module Tools
      class RandomPicker < Tool
        def self.signature
          {
            name: name,
            description:
              "Handles a variety of random decisions based on the format of each input element",
            parameters: [
              {
                name: "options",
                description:
                  "An array where each element is either a range (e.g., '1-6') or a comma-separated list of options (e.g., 'sam,jane,joe')",
                type: "array",
                item_type: "string",
                required: true,
              },
            ],
          }
        end

        def self.name
          "random_picker"
        end

        def options
          parameters[:options]
        end

        def invoke
          result = nil
          # can be a naive list of strings
          if options.none? { |option| option.match?(/\A\d+-\d+\z/) || option.include?(",") }
            result = options.sample
          else
            result =
              options.map do |option|
                case option
                when /\A\d+-\d+\z/ # Range format, e.g., "1-6"
                  random_range(option)
                when /,/ # Comma-separated values, e.g., "sam,jane,joe"
                  pick_list(option)
                else
                  "Invalid format: #{option}"
                end
              end
          end

          @last_result = result
          { options: options, result: result }
        end

        private

        def random_range(range_str)
          low, high = range_str.split("-").map(&:to_i)
          rand(low..high)
        end

        def pick_list(list_str)
          list_str.split(",").map(&:strip).sample
        end

        def description_args
          { options: options, result: @last_result }
        end
      end
    end
  end
end
