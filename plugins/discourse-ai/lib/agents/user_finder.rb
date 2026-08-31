# frozen_string_literal: true

module DiscourseAi
  module Agents
    class UserFinder
      DEFAULT_LIMIT = 50
      MAX_LIMIT = 100
      MAX_CATEGORY_PERMISSION_CANDIDATES = 500

      def initialize(params, guardian: Guardian.new)
        @params = params.is_a?(Hash) ? params.with_indifferent_access : {}
        @guardian = guardian
      end

      def call
        limit = parsed_limit
        return limit if limit[:error]

        groups = requested_groups
        return groups if groups[:error]

        category = requested_category
        return category if category[:error]

        users = User.human_users
        users = filter_by_status(users)
        users = filter_by_query(users)
        users = filter_by_groups(users, groups[:groups])
        users =
          users.order(:username_lower).limit(candidate_limit(limit[:limit], category[:category]))
        users = filter_by_category_permission(users, category[:category], limit[:limit])

        users = users.to_a
        real_user_ids = User.real.where(id: users.map(&:id)).pluck(:id).to_set

        { users: users.map { |user| serialize_user(user, real: real_user_ids.include?(user.id)) } }
      end

      private

      def parsed_limit
        limit = @params.fetch(:limit, DEFAULT_LIMIT).to_i
        return { error: "limit must be greater than 0" } if limit <= 0

        { limit: [limit, MAX_LIMIT].min }
      end

      def requested_groups
        group_identifiers = Array(@params[:groups]).flat_map { |group| group.to_s.split(",") }
        group_identifiers.map!(&:strip)
        group_identifiers.reject!(&:blank?)

        groups =
          group_identifiers.map do |identifier|
            if identifier.match?(/\A\d+\z/)
              Group.find_by(id: identifier.to_i)
            else
              Group.find_by(name: identifier) ||
                (Group[identifier.to_sym] if Group::AUTO_GROUPS.key?(identifier.to_sym))
            end
          end

        missing_groups =
          group_identifiers.zip(groups).filter_map { |identifier, group| identifier if group.nil? }

        return { error: "Group not found: #{missing_groups.join(", ")}" } if missing_groups.any?

        { groups: groups }
      end

      def requested_category
        category_id = @params[:category_id]
        category_name = @params[:category_name]
        return { category: nil } if category_id.blank? && category_name.blank?

        category = find_category(category_id.presence || category_name)
        return { error: "Category not found" } if category.nil?
        return { error: "Category not found" } if !@guardian.can_see_category?(category)

        { category: category }
      end

      def find_category(category_id_or_name)
        if category_id_or_name.is_a?(Integer) ||
             category_id_or_name.to_i.to_s == category_id_or_name.to_s
          Category.find_by(id: category_id_or_name.to_i)
        else
          Category
            .where(name: category_id_or_name)
            .or(Category.where(slug: category_id_or_name))
            .first
        end
      end

      def filter_by_query(users)
        query = @params[:query].to_s.strip
        return users if query.blank?

        query_like = "%#{ActiveRecord::Base.sanitize_sql_like(query.downcase)}%"
        users.where(
          "users.username_lower LIKE :query OR users.name ILIKE :query",
          query: query_like,
        )
      end

      def filter_by_status(users)
        if @params.key?(:active)
          users = users.where(active: ActiveModel::Type::Boolean.new.cast(@params[:active]))
        end

        if @params.key?(:staged)
          users = users.where(staged: ActiveModel::Type::Boolean.new.cast(@params[:staged]))
        end

        if @params.key?(:suspended)
          suspended = ActiveModel::Type::Boolean.new.cast(@params[:suspended])
          users = suspended ? users.suspended : users.not_suspended
        end

        if @params.key?(:real)
          users =
            if ActiveModel::Type::Boolean.new.cast(@params[:real])
              users.where(
                "NOT EXISTS(
                  SELECT 1
                  FROM anonymous_users a
                  WHERE a.user_id = users.id
                )",
              )
            else
              users.where(
                "EXISTS(
                  SELECT 1
                  FROM anonymous_users a
                  WHERE a.user_id = users.id
                )",
              )
            end
        end

        users
      end

      def filter_by_groups(users, groups)
        return users if groups.blank?

        users.joins(:group_users).where(group_users: { group_id: groups.map(&:id) }).distinct
      end

      def candidate_limit(limit, category)
        return limit if category.nil?

        [limit * 10, MAX_CATEGORY_PERMISSION_CANDIDATES].min
      end

      def filter_by_category_permission(users, category, limit)
        return users if category.nil?

        users.select { |user| Guardian.new(user).can_create?(Topic, category) }.first(limit)
      end

      def serialize_user(user, real:)
        {
          id: user.id,
          username: user.username,
          name: user.name,
          active: user.active,
          staged: user.staged,
          suspended: user.suspended?,
          real: real,
        }
      end
    end
  end
end
