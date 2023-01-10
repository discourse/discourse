# frozen_string_literal: true

module Reports::Flags
  extend ActiveSupport::Concern

  class_methods do
    def report_flags(report)
      category_id, include_subcategories = report.add_category_filter

      report.icon = "flag"
      report.higher_is_better = false

      basic_report_about(
        report,
        ReviewableFlaggedPost,
        :count_by_date,
        report.start_date,
        report.end_date,
        category_id,
        include_subcategories,
      )

      countable = ReviewableFlaggedPost.scores_with_topics

      if category_id
        if include_subcategories
          countable =
            countable.where("topics.category_id IN (?)", Category.subcategory_ids(category_id))
        else
          countable = countable.where("topics.category_id = ?", category_id)
        end
      end

      add_counts report, countable, "reviewable_scores.created_at"
    end
  end
end
