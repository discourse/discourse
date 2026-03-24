# frozen_string_literal: true

module DiscourseAi
  module Agents
    module Tools
      class ListCategories < Tool
        def self.signature
          {
            name: name,
            description:
              "Will list the categories on the current discourse instance, prefer to format with # in front of the category name",
          }
        end

        def self.name
          "categories"
        end

        def invoke
          columns = {
            name: "Name",
            slug: "Slug",
            description: "Description",
            posts_year: "Posts Year",
            posts_month: "Posts Month",
            posts_week: "Posts Week",
            id: "id",
            parent_category_id: "parent_category_id",
          }

          rows = Category.where(read_restricted: false).limit(100).pluck(*columns.keys)

          @last_count = rows.length

          { rows: rows, column_names: columns.values }
        end

        private

        def description_args
          { count: @last_count || 0 }
        end
      end
    end
  end
end
