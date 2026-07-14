# frozen_string_literal: true

module Reports::PostersByMemberType
  extend ActiveSupport::Concern

  MEMBER_TYPES = %i[new_members returning staff].freeze

  class_methods do
    def report_posters_by_member_type(report)
      report.modes = [Report::MODES[:table]]
      report.labels = [
        { property: :name, title: I18n.t("reports.posters_by_member_type.labels.member_type") },
        {
          property: :count,
          type: :number,
          title: I18n.t("reports.posters_by_member_type.labels.count"),
        },
        {
          property: :share_formatted,
          title: I18n.t("reports.posters_by_member_type.labels.share"),
        },
      ]

      category_id, include_subcategories = report.add_category_filter

      builder = DB.build <<~SQL
        SELECT
          CASE
            WHEN u.admin OR u.moderator THEN 'staff'
            WHEN u.created_at >= :start_date THEN 'new_members'
            ELSE 'returning'
          END AS bucket,
          COUNT(*) AS post_count
        FROM posts p
        INNER JOIN topics t ON t.id = p.topic_id
        INNER JOIN users u ON u.id = p.user_id
        /*join*/
        /*where*/
        GROUP BY bucket
      SQL

      builder.where("p.created_at >= :start_date", start_date: report.start_date)
      builder.where("p.created_at <= :end_date", end_date: report.end_date)
      builder.where("p.deleted_at IS NULL")
      builder.where("p.post_type = :regular_post_type", regular_post_type: Post.types[:regular])
      builder.where("t.deleted_at IS NULL")
      builder.where("t.archetype = 'regular'")
      builder.where("u.id > 0")

      if category_id
        if include_subcategories
          builder.where(
            "t.category_id IN (:category_ids)",
            category_ids: Category.subcategory_ids(category_id),
          )
        else
          builder.where("t.category_id = :category_id", category_id: category_id)
        end
      end

      unless report.current_user&.admin?
        builder.join "categories c ON c.id = t.category_id"
        builder.secure_category(Guardian.new(report.current_user).secure_category_ids)
      end

      counts = Hash.new(0)
      builder.query.each { |row| counts[row.bucket.to_sym] = row.post_count }

      total = counts.values.sum
      report.total = total

      report.data =
        MEMBER_TYPES.map do |type|
          count = counts[type]
          share = total.zero? ? 0.0 : (count.to_f / total * 100).round(2)
          {
            type: type,
            name: I18n.t("reports.posters_by_member_type.types.#{type}"),
            count: count,
            share: share,
            share_formatted: "#{share}%",
          }
        end
    end
  end
end
