# frozen_string_literal: true

module DiscourseEvents
  module Configuration
    class MapEventsTitleJsonSchema
      class << self
        def schema
          @schema ||= {
            type: "array",
            uniqueItems: true,
            items: {
              type: "object",
              title: "Title Mapping",
              properties: {
                category_slug: {
                  type: "string",
                  description: "Slug of the category",
                },
                custom_title: {
                  type: "string",
                  default: "Upcoming events",
                  description:
                    "The words you want to replace 'Upcoming Events' with for the sidebar calendar",
                },
              },
              required: %w[category_slug custom_title],
            },
          }
        end
      end
    end
  end
end
