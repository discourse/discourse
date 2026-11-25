# frozen_string_literal: true

module Jobs
  class RefreshCategoryLikeStats < ::Jobs::Base
    def execute(args)
      topic_ids = args[:topic_ids]
      category_ids = args[:category_ids]
      return if topic_ids.blank? && category_ids.blank?

      topics = Topic.with_deleted
      topics = topics.where(id: topic_ids) if topic_ids.present?
      topics = topics.where(category_id: category_ids) if category_ids.present?
      posts = Post.with_deleted.where(topic_id: topics.select(:id))
      user_ids =
        UserAction.where(
          action_type: UserAction::LIKE_ACTION_TYPES,
          target_post_id: posts.select(:id),
        ).select(:user_id)

      UserStat
        .where(user_id: user_ids)
        .in_batches do |stats|
          UserStat.transaction do
            # Rows can change while the recount waits for a concurrent like or unlike.
            ids = stats.order(:user_id).lock.pluck(:user_id)
            UserStat.recalculate_likes!(ids) if ids.present?
          end
        end

      DirectoryItem.refresh! if category_ids.present? && SiteSetting.enable_user_directory?
    end
  end
end
