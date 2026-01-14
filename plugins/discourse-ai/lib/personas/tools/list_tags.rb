#frozen_string_literal: true

module DiscourseAi
  module Personas
    module Tools
      class ListTags < Tool
        def self.signature
          {
            name: name,
            description: "Will list the 100 most popular tags on the current discourse instance",
          }
        end

        def self.name
          "tags"
        end

        def invoke
          column_names = { name: "Name", public_topic_count: "Topic Count" }

          tags =
            Tag
              .where("public_topic_count > 0")
              .order(public_topic_count: :desc)
              .limit(100)
              .pluck(*column_names.keys)

          @last_count = tags.length

          format_results(tags, column_names.values)
        end

        private

        def description_args
          { count: @last_count || 0 }
        end
      end
    end
  end
end
