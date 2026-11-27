# frozen_string_literal: true

module DiscourseAssign
  module Visibility
    class << self
      # Mirrors the visibility used by assign reminders: `Topic.secured` only
      # covers categories, private messages additionally require participation.
      def visible_topic_ids(guardian)
        return Topic.secured(guardian).select(:id) if guardian.is_admin?

        scope = Topic.listable_topics.secured(guardian)
        scope = scope.or(Topic.private_messages_for_user(guardian.user)) if guardian.user
        scope.select(:id)
      end

      def visible_post_ids(guardian)
        Post.secured(guardian).select(:id)
      end

      # SQL condition for assignment rows joined under `table_alias`, matching
      # assignments whose target the guardian can see.
      def visible_assignments_sql(guardian, table_alias: "assignments")
        topics = visible_topic_ids(guardian).to_sql
        posts = visible_post_ids(guardian).to_sql

        "(#{table_alias}.topic_id IN (#{topics}) AND (#{table_alias}.target_type <> 'Post' " \
          "OR #{table_alias}.target_id IN (#{posts})))"
      end

      # Users who can see `target`, mirroring `Guardian#can_see?` as a relation so
      # callers can intersect SQL-backed audiences without loading every user and
      # running a guardian lookup per user.
      def visible_users(target)
        case target
        when Post
          post_visible_users(target)
        when Topic
          topic_visible_users(target)
        else
          no_users
        end
      end

      # True when every topic reader can see `target`, so callers can skip the
      # visibility join entirely.
      def visible_to_all_users?(target)
        case target
        when Post
          !target.whisper? && !target.hidden? && !target.trashed? &&
            visible_to_all_users?(target.topic)
        when Topic
          !target.private_message? && target.deleted_at.nil? && !target.shared_draft? &&
            target.category.present? && !target.category.read_restricted?
        else
          false
        end
      end

      private

      def user_scope
        User.unscoped.select(:id)
      end

      def no_users
        user_scope.where("1 = 0")
      end

      def any_of(*scopes)
        scopes.compact.reduce { |combined, scope| combined.or(scope) }
      end

      def group_members(group_ids)
        ids = Array(group_ids).map(&:to_i).uniq
        return no_users if ids.empty?

        if ids.include?(Group::AUTO_GROUPS[:everyone]) ||
             ids.include?(Group::AUTO_GROUPS[:logged_in_users])
          return user_scope
        end

        user_scope.where(id: GroupUser.where(group_id: ids).select(:user_id))
      end

      def admins
        user_scope.where(admin: true)
      end

      def topic_visible_users(topic)
        return no_users if topic.nil?

        audience =
          if topic.deleted_at.present?
            deleted_topic_audience(topic)
          elsif topic.private_message?
            user_scope.where(id: topic.all_allowed_users.select(:id))
          else
            category_audience(topic.category)
          end

        audience = audience.where(id: shared_draft_audience) if topic.shared_draft?

        any_of(admins_for_topics, audience)
      end

      def admins_for_topics
        SiteSetting.suppress_secured_categories_from_admin ? no_users : admins
      end

      def category_audience(category)
        return no_users if category.nil?
        return user_scope if !category.read_restricted?

        group_members(CategoryGroup.where(category_id: category.id).pluck(:group_id))
      end

      def deleted_topic_audience(topic)
        any_of(
          category_group_moderators(topic.category),
          group_members(SiteSetting.delete_all_posts_and_topics_allowed_groups_map),
        )
      end

      def shared_draft_audience
        group_members(SiteSetting.shared_drafts_allowed_groups_map)
      end

      def category_group_moderators(category)
        return no_users if category.nil? || !SiteSetting.enable_category_group_moderation

        group_members(CategoryModerationGroup.where(category_id: category.id).pluck(:group_id))
      end

      def post_visible_users(post)
        return no_users if post.nil?

        topic = post.topic || Topic.with_deleted.find_by(id: post.topic_id)
        readers = any_of(topic_visible_users(topic), admins)

        readers = readers.where(id: whisperers) if post.post_type == Post.types[:whisper]
        readers = readers.where(id: post_moderators(topic)) if post.trashed?

        if post.hidden?
          readers =
            readers.where(
              id:
                any_of(
                  post_moderators(topic),
                  group_members(SiteSetting.hidden_post_visible_groups_map),
                  user_scope.where(id: post.user_id),
                ),
            )
        end

        readers
      end

      def post_moderators(topic)
        any_of(
          admins,
          user_scope.where(moderator: true),
          category_group_moderators(topic&.category),
        )
      end

      def whisperers
        group_ids = SiteSetting.whispers_allowed_groups_map.map(&:to_i)
        group_ids -= [
          Group::AUTO_GROUPS[:everyone],
          Group::AUTO_GROUPS[:anonymous_users],
          Group::AUTO_GROUPS[:logged_in_users],
        ]
        return admins if group_ids.empty?

        any_of(admins, group_members(group_ids))
      end
    end
  end
end
