# frozen_string_literal: true

class Jobs::NotifyReviewable < ::Jobs::Base
  # this job can take a very long time if there are many mods
  # do not swamp the queue with it
  cluster_concurrency 1

  def execute(args)
    return unless reviewable = Reviewable.find_by(id: args[:reviewable_id])

    @contacted = Set.new

    all_updates = Hash.new { |h, k| h[k] = {} }

    if args[:updated_reviewable_ids].present?
      Reviewable
        .where(id: args[:updated_reviewable_ids])
        .each do |r|
          payload = { last_performing_username: args[:performing_username], status: r.status }

          all_updates[:admins][r.id] = payload
          all_updates[:moderators][r.id] = payload if r.reviewable_by_moderator?

          if SiteSetting.enable_category_group_moderation? && r.category.present?
            r
              .category
              .moderating_groups
              .pluck(:id)
              .each { |group_id| all_updates[group_id][r.id] = payload }
          end
        end
    end

    DistributedMutex.synchronize("notify_reviewable_job", validity: 120) do
      notify_users(User.real.admins, all_updates[:admins])

      if reviewable.reviewable_by_moderator?
        notify_users(
          User.real.moderators.where("id NOT IN (?)", @contacted),
          all_updates[:moderators],
        )
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
            .where("users.id NOT IN (?)", @contacted)
            .distinct

        users.find_each do |user|
          updates = {}
          user.group_users.each { |gu| updates.merge!(all_updates[gu.group_id]) }

          notify_user(user, updates)
        end

        @contacted += users.pluck(:id)
      end
    end
  end

  protected

  def notify_users(users, updates)
    users.find_each { |user| notify_user(user, updates) }
    @contacted += users.pluck(:id)
  end

  def notify_user(user, updates)
    user.publish_reviewable_counts(updates.present? ? { updates: updates } : nil)
  end
end
