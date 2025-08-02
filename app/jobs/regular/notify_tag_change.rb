# frozen_string_literal: true

module Jobs
  class NotifyTagChange < ::Jobs::Base
    def execute(args)
      return if SiteSetting.disable_tags_edit_notifications && !args[:force]

      post = Post.find_by(id: args[:post_id])

      if post&.topic&.visible?
        post_alerter = PostAlerter.new
        post_alerter.notify_post_users(
          post,
          User.where(id: args[:notified_user_ids]),
          group_ids: all_tags_in_hidden_groups?(args) ? tag_group_ids(args) : nil,
          include_topic_watchers: !post.topic.private_message?,
          include_category_watchers: false,
        )
        post_alerter.notify_first_post_watchers(post, post_alerter.tag_watchers(post.topic))
      end
    end

    private

    def all_tags_in_hidden_groups?(args)
      return false if args[:diff_tags].blank?

      Tag
        .where(name: args[:diff_tags])
        .joins(tag_groups: :tag_group_permissions)
        .where.not(tag_group_permissions: { group_id: 0 })
        .distinct
        .count == args[:diff_tags].count
    end

    def tag_group_ids(args)
      Tag
        .where(name: args[:diff_tags])
        .joins(tag_groups: :tag_group_permissions)
        .pluck("tag_group_permissions.group_id")
    end
  end
end
