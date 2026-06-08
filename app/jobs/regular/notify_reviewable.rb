# frozen_string_literal: true

class Jobs::NotifyReviewable < ::Jobs::Base
  # this job can take a very long time if there are many mods
  # do not swamp the queue with it
  cluster_concurrency 1

  def execute(args)
    return unless reviewable = Reviewable.find_by(id: args[:reviewable_id])

    @contacted = Set.new
    @remove_reviewable_ids = args[:remove_reviewable_ids] || []

    DistributedMutex.synchronize("notify_reviewable_job", validity: 120) do
      notify_users(User.real.admins)

      if reviewable.reviewable_by_moderator?
        notify_users(User.real.moderators.where.not(id: @contacted))
      end

      if SiteSetting.enable_category_group_moderation? && reviewable.category.present?
        users =
          User
            .includes(:group_users)
            .joins(:group_users)
            .joins(
              "INNER JOIN category_moderation_groups ON category_moderation_groups.group_id = group_users.group_id",
            )
            .where("category_moderation_groups.category_id": reviewable.category.id)
            .where.not(id: @contacted)
            .distinct

        users.find_each { |user| notify_user(user) }
        @contacted += users.pluck(:id)
      end
    end
  end

  protected

  def notify_users(users)
    users.find_each { |user| notify_user(user) }
    @contacted += users.pluck(:id)
  end

  def notify_user(user)
    data = {}
    data[:remove_reviewable_ids] = @remove_reviewable_ids if @remove_reviewable_ids.present?

    user.publish_reviewable_counts(data.presence)
  end
end
