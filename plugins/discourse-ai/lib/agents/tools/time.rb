#frozen_string_literal: true

module DiscourseAi
  module Agents
    module Tools
      class Time < Tool
        def self.signature
          {
            name: name,
            description: "Will generate the time in a timezone",
            parameters: [
              {
                name: "timezone",
                description: "ALWAYS supply a Ruby compatible timezone",
                type: "string",
                required: true,
              },
            ],
          }
        end

        def self.name
          "time"
        end

        def timezone
          parameters[:timezone].to_s
        end

        def invoke
          time =
            begin
              ::Time.now.in_time_zone(timezone)
            rescue StandardError
              nil
            end
          time = ::Time.now if !time

          @last_time = time.to_s

          { args: { timezone: timezone }, time: time.to_s }
        end

        private

        def description_args
          { timezone: timezone, time: @last_time }
        end
      end
    end
  end
end
