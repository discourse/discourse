# frozen_string_literal: true

module DiscourseRewind
  module Action
    class MostViewedCategories < BaseReport
      FakeData = {
        data: [
          { category_id: 1, name: "cats" },
          { category_id: 2, name: "dogs" },
          { category_id: 3, name: "countries" },
          { category_id: 4, name: "management" },
        ],
        identifier: "most-viewed-categories",
      }

      def call
        return FakeData if should_use_fake_data?

        most_viewed_categories =
          TopicViewItem
            .joins(topic: :category)
            .merge(self.class.public_categories)
            .where(user:, viewed_at: date)
            .group("categories.id, categories.name")
            .order("COUNT(*) DESC, categories.id")
            .limit(4)
            .pluck("categories.id, categories.name")
            .map { |category_id, name| { category_id:, name: } }

        { data: most_viewed_categories, identifier: "most-viewed-categories" }
      end

      def self.public_categories
        Category.where(read_restricted: false)
      end

      def self.filter_for_viewer(report, **)
        public_category_ids =
          public_categories.where(id: report[:data].pluck(:category_id)).pluck(:id)

        report.merge(
          data: report[:data].select { |category| category[:category_id].in?(public_category_ids) },
        )
      end
    end
  end
end
