# frozen_string_literal: true

module DiscourseAi
  module Agents
    module Tools
      class FindCategory < Tool
        MAX_RESULTS = 10

        # Matches the parameter names of set_category_permissions.
        LEVEL_NAMES = {
          CategoryGroup.permission_types[:full] => "create_reply_see",
          CategoryGroup.permission_types[:create_post] => "reply_see",
          CategoryGroup.permission_types[:readonly] => "see",
        }.freeze

        COLUMN_NAMES = %w[
          id
          name
          slug
          url
          parent_category_id
          private
          permissions
          topic_count
          subcategory_count
        ].freeze

        def self.signature
          {
            name: name,
            description:
              "Finds categories by name or slug, including private ones, and returns each one's ID, URL, parent, whether it is private, which groups can access it, and how many topics and subcategories it has. Use it to look up a category before changing its permissions or deleting it.",
            parameters: [
              {
                name: "query",
                description: "Part of the category's name or slug",
                type: "string",
                required: true,
              },
            ],
          }
        end

        def self.name
          "find_category"
        end

        # Results can include private categories, so the tool is only offered
        # to people who manage categories, in conversations nobody else reads.
        def self.available_for_context?(context)
          user = context&.user
          return false if !user || !user.guardian.can_create_category?

          private_conversation?(context)
        end

        # A private message or chat direct message between the user and bots
        # only. Other members would see results only the user is allowed to see.
        def self.private_conversation?(context)
          member_ids =
            if context.channel_id.present?
              return false if !defined?(Chat::Channel)
              channel = Chat::Channel.find_by(id: context.channel_id)
              return false if !channel&.direct_message_channel?
              channel.allowed_user_ids
            elsif context.private_message? && (topic = Topic.find_by(id: context.topic_id))
              return false if topic.topic_allowed_groups.exists?
              topic.topic_allowed_users.pluck(:user_id)
            else
              return false
            end

          member_ids.all? { |id| id == context.user.id || !User.human_user_id?(id) }
        end

        def invoke
          if !self.class.available_for_context?(context)
            return error_response(I18n.t("discourse_ai.ai_bot.find_category.errors.not_allowed"))
          end

          query = parameters[:query].to_s.strip
          if query.blank?
            return error_response(I18n.t("discourse_ai.ai_bot.find_category.errors.no_query"))
          end

          categories = matching_categories(query)
          @last_count = categories.size

          if categories.empty?
            return(
              { rows: [], message: I18n.t("discourse_ai.ai_bot.find_category.no_results", query:) }
            )
          end

          { rows: rows(categories), column_names: COLUMN_NAMES }
        end

        private

        def description_args
          { count: @last_count || 0, query: parameters[:query].to_s }
        end

        def matching_categories(query)
          term = "%#{ActiveRecord::Base.sanitize_sql_like(query)}%"

          Category
            .secured(guardian)
            .where("categories.name ILIKE :term OR categories.slug ILIKE :term", term:)
            .includes(:parent_category, category_groups: :group)
            .order(
              Arel.sql(
                ActiveRecord::Base.sanitize_sql_array(
                  ["LOWER(categories.name) = ? DESC, categories.name", query.downcase],
                ),
              ),
            )
            .limit(MAX_RESULTS * 2)
            .select { |category| guardian.can_edit_category?(category) }
            .first(MAX_RESULTS)
        end

        def rows(categories)
          ids = categories.map(&:id)
          topic_counts =
            Topic
              .where(category_id: ids)
              .where.not(id: categories.map(&:topic_id).compact)
              .group(:category_id)
              .count
          subcategory_counts =
            Category.where(parent_category_id: ids).group(:parent_category_id).count

          categories.map do |category|
            [
              category.id,
              category.name,
              category.slug,
              "#{Discourse.base_url_no_prefix}#{category.url}",
              category.parent_category_id,
              category.read_restricted,
              describe_permissions(category),
              topic_counts[category.id] || 0,
              subcategory_counts[category.id] || 0,
            ]
          end
        end

        # A category without group permissions is open to everyone, unless it
        # is restricted, in which case only administrators can see it.
        def describe_permissions(category)
          groups = category.category_groups.select(&:group)
          if groups.empty?
            return category.read_restricted ? "administrators only" : "everyone: create_reply_see"
          end

          groups
            .sort_by do |category_group|
              [category_group.permission_type, category_group.group.name]
            end
            .map do |category_group|
              "#{category_group.group.name}: #{LEVEL_NAMES[category_group.permission_type]}"
            end
            .join(", ")
        end
      end
    end
  end
end
