# frozen_string_literal: true

# Topics visited grouped by category
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
            .joins(:topic)
            .joins("INNER JOIN categories ON categories.id = topics.category_id")
            .where(
              user: user,
              viewed_at: date,
              categories: {
                id: user.guardian.allowed_category_ids,
              },
            )
            .group("categories.id, categories.name")
            .order("COUNT(*) DESC")
            .limit(4)
            .pluck("categories.id, categories.name")
            .map { |category_id, name| { category_id: category_id, name: name } }

        { data: most_viewed_categories, identifier: "most-viewed-categories" }
      end
    end
  end
end
