# frozen_string_literal: true

module Reports::PostersByMemberType
  extend ActiveSupport::Concern

  SYNTHETIC_KEYS = %w[new_members returning staff].freeze
  DEFAULT_GROUPS = SYNTHETIC_KEYS
  MAX_GROUPS = 10
  MAX_CATEGORY_IDS = 50
  MAX_MEMBER_ROWS = 500

  EXCLUDED_GROUP_IDS = [
    Group::AUTO_GROUPS[:everyone],
    Group::AUTO_GROUPS[:anonymous_users],
    Group::AUTO_GROUPS[:logged_in_users],
    Group::AUTO_GROUPS[:staff],
  ].freeze

  class_methods do
    def group_token(group_id)
      "group:#{group_id}"
    end

    def parse_group_token(token)
      token = token.to_s
      return { type: :synthetic, key: token } if SYNTHETIC_KEYS.include?(token)

      match = token.match(/\Agroup:(\d+)\z/)
      { type: :group, id: match[1].to_i } if match
    end

    def valid_group_token?(token)
      parsed = parse_group_token(token)
      return false if parsed.nil?
      return true if parsed[:type] == :synthetic

      !EXCLUDED_GROUP_IDS.include?(parsed[:id]) && Group.exists?(id: parsed[:id])
    end

    def report_posters_by_member_type(report)
      report.modes = ["posters_by_member_type"]
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

      category_ids, empty_category_selection = parse_category_ids_filter(report)
      report.add_filter("category_ids", type: "category_list", default: category_ids)

      guardian = report.guardian || Guardian.new(report.current_user)
      resolved_groups = resolve_groups_filter(report.filters[:groups], guardian)
      report.add_filter("groups", type: "groups", default: resolved_groups)

      synthetic_keys = resolved_groups & SYNTHETIC_KEYS
      group_ids =
        resolved_groups.filter_map do |token|
          parsed = parse_group_token(token)
          parsed[:id] if parsed && parsed[:type] == :group
        end
      groups_by_id = Group.where(id: group_ids).index_by(&:id)

      counts = {}
      total = 0

      unless empty_category_selection
        if synthetic_keys.present?
          counts.merge!(synthetic_bucket_counts(report, category_ids, guardian))
        end

        if group_ids.present?
          group_post_counts(report, category_ids, guardian, group_ids).each do |group_id, count|
            counts[group_token(group_id)] = count
          end
        end

        total = grand_total(report, category_ids, guardian)
      end

      report.total = total

      report.data =
        resolved_groups.filter_map do |token|
          if SYNTHETIC_KEYS.include?(token)
            kind = "synthetic"
            group_id = nil
            name = I18n.t("reports.posters_by_member_type.types.#{token}")
          elsif (parsed = parse_group_token(token)) && parsed[:type] == :group &&
                (group = groups_by_id[parsed[:id]])
            kind = "group"
            group_id = group.id
            name = group.name_full_preferred
          else
            next
          end

          count = counts[token] || 0
          share = total.zero? ? 0.0 : (count.to_f / total * 100).round(2)

          {
            type: token,
            kind: kind,
            group_id: group_id,
            name: name,
            count: count,
            share: share,
            share_formatted: "#{share}%",
          }
        end
    end

    def report_posters_by_member_type_members(report)
      report.modes = [Report::MODES[:table]]
      report.labels = [
        {
          type: :user,
          properties: {
            username: :username,
            id: :user_id,
            avatar: :avatar_template,
          },
          title: I18n.t("reports.posters_by_member_type_members.labels.user"),
        },
        {
          property: :count,
          type: :number,
          title: I18n.t("reports.posters_by_member_type_members.labels.count"),
        },
        {
          property: :share_formatted,
          title: I18n.t("reports.posters_by_member_type_members.labels.share"),
        },
      ]

      category_ids, empty_category_selection = parse_category_ids_filter(report)
      report.add_filter("category_ids", type: "category_list", default: category_ids)

      guardian = report.guardian || Guardian.new(report.current_user)
      parsed = parse_group_token(report.filters[:group])

      if parsed.nil?
        report.error = :not_found
        return
      end

      if parsed[:type] == :group
        group = Group.find_by(id: parsed[:id])
        if group.nil? || EXCLUDED_GROUP_IDS.include?(group.id) ||
             !(guardian.is_admin? || guardian.can_see_group_and_members?(group))
          report.error = :not_found
          return
        end
      end

      report.total = 0
      report.data = []
      return if empty_category_selection

      rows = member_rows_for(report, category_ids, guardian, parsed)
      total = member_total_for(report, category_ids, guardian, parsed)
      report.total = total

      report.data =
        rows.map do |row|
          share = total.zero? ? 0.0 : (row[:count].to_f / total * 100).round(2)
          row.merge(share: share, share_formatted: "#{share}%")
        end
    end

    private

    def parse_category_ids_filter(report)
      raw_ids = report.filters[:category_ids]
      return nil, false if raw_ids.blank?

      parsed_ids = Array(raw_ids.is_a?(String) ? raw_ids.split(",") : raw_ids).map(&:to_i)
      ids =
        if parsed_ids.present?
          # in_order_of keeps the admin's requested order and drops nonexistent ids
          Category.in_order_of(:id, parsed_ids).limit(MAX_CATEGORY_IDS).pluck(:id)
        else
          []
        end

      [ids, ids.empty?]
    end

    def resolve_groups_filter(raw_groups, guardian)
      tokens =
        Array(raw_groups.is_a?(String) ? raw_groups.split(",") : raw_groups)
          .map { |token| token.to_s.strip }
          .reject(&:blank?)
          .uniq
          .first(MAX_GROUPS)

      requested_group_ids =
        tokens.filter_map do |token|
          parse_group_token(token)&.dig(:id) if token.start_with?("group:")
        end

      visible_group_ids =
        if requested_group_ids.present?
          Group
            .where(id: requested_group_ids)
            .where.not(id: EXCLUDED_GROUP_IDS)
            .select { |group| guardian.is_admin? || guardian.can_see_group_and_members?(group) }
            .map(&:id)
            .to_set
        else
          Set.new
        end

      resolved =
        tokens.select do |token|
          parsed = parse_group_token(token)
          next false if parsed.nil?
          parsed[:type] == :synthetic || visible_group_ids.include?(parsed[:id])
        end

      resolved.presence || DEFAULT_GROUPS.dup
    end

    def base_query_builder(report, category_ids, guardian)
      builder = DB.build(<<~SQL)
        /*select*/
        FROM posts p
        INNER JOIN topics t ON t.id = p.topic_id
        INNER JOIN users u ON u.id = p.user_id
        /*join*/
        /*where*/
        /*group_by*/
        /*order_by*/
        /*limit*/
      SQL

      builder.where("p.created_at >= :start_date", start_date: report.start_date)
      builder.where("p.created_at <= :end_date", end_date: report.end_date)
      builder.where("p.deleted_at IS NULL")
      builder.where("p.post_type = :regular_post_type", regular_post_type: Post.types[:regular])
      builder.where("t.deleted_at IS NULL")
      builder.where("t.archetype = 'regular'")
      builder.where("u.id > 0")
      if category_ids.present?
        builder.where("t.category_id IN (:category_ids)", category_ids: category_ids)
      end

      unless guardian.is_admin?
        builder.join "categories c ON c.id = t.category_id"
        builder.secure_category(guardian.secure_category_ids)
      end

      builder
    end

    def grand_total(report, category_ids, guardian)
      base_query_builder(report, category_ids, guardian).count.to_i
    end

    def synthetic_bucket_counts(report, category_ids, guardian)
      rows =
        base_query_builder(report, category_ids, guardian).select(<<~SQL).group_by("bucket").query
            CASE
              WHEN u.admin OR u.moderator THEN 'staff'
              WHEN u.created_at >= :start_date THEN 'new_members'
              ELSE 'returning'
            END AS bucket,
            COUNT(*) AS post_count
          SQL

      rows.each_with_object({}) { |row, counts| counts[row.bucket] = row.post_count }
    end

    def group_post_counts(report, category_ids, guardian, group_ids)
      rows =
        base_query_builder(report, category_ids, guardian)
          .join(
            "group_users gu ON gu.user_id = u.id AND gu.group_id IN (:group_ids)",
            group_ids: group_ids,
          )
          .select("gu.group_id, COUNT(*) AS post_count")
          .group_by("gu.group_id")
          .query

      rows.each_with_object({}) { |row, counts| counts[row.group_id] = row.post_count }
    end

    def apply_entry_scope(builder, report, parsed)
      if parsed[:type] == :group
        builder.join(
          "group_users gu ON gu.user_id = u.id AND gu.group_id = :group_id",
          group_id: parsed[:id],
        )
      else
        case parsed[:key]
        when "staff"
          builder.where("u.admin OR u.moderator")
        when "new_members"
          builder.where("NOT (u.admin OR u.moderator)")
          builder.where("u.created_at >= :start_date", start_date: report.start_date)
        when "returning"
          builder.where("NOT (u.admin OR u.moderator)")
          builder.where("u.created_at < :start_date", start_date: report.start_date)
        end
      end

      builder
    end

    def member_total_for(report, category_ids, guardian, parsed)
      apply_entry_scope(
        base_query_builder(report, category_ids, guardian),
        report,
        parsed,
      ).count.to_i
    end

    def member_rows_for(report, category_ids, guardian, parsed)
      builder =
        apply_entry_scope(base_query_builder(report, category_ids, guardian), report, parsed)

      builder
        .select("u.id AS user_id, u.username, u.uploaded_avatar_id, COUNT(*) AS post_count")
        .group_by("u.id, u.username, u.uploaded_avatar_id")
        .order_by("post_count DESC")
        .limit(MAX_MEMBER_ROWS)
        .query
        .map do |row|
          {
            user_id: row.user_id,
            username: row.username,
            avatar_template: User.avatar_template(row.username, row.uploaded_avatar_id),
            count: row.post_count,
          }
        end
    end
  end
end
