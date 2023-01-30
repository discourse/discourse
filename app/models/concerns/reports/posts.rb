# frozen_string_literal: true

module Reports::Posts
  extend ActiveSupport::Concern

  class_methods do
    def report_posts(report)
      report.modes = %i[table chart]

      category_id, include_subcategories = report.add_category_filter

      basic_report_about report,
                         Post,
                         :public_posts_count_per_day,
                         report.start_date,
                         report.end_date,
                         category_id,
                         include_subcategories

      countable = Post.public_posts.where(post_type: Post.types[:regular])
      if category_id
        if include_subcategories
          countable =
            countable.joins(:topic).where(
              "topics.category_id IN (?)",
              Category.subcategory_ids(category_id),
            )
        else
          countable = countable.joins(:topic).where("topics.category_id = ?", category_id)
        end
      end

      add_counts report, countable, "posts.created_at"
    end
  end
end
