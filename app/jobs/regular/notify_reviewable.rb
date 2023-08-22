# frozen_string_literal: true

class Jobs::NotifyReviewable < ::Jobs::Base
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
          all_updates[r.reviewable_by_group_id][r.id] = payload if r.reviewable_by_group_id
        end
    end

    DistributedMutex.synchronize("notify_reviewable_job", validity: 120) do
      counts = Hash.new(0)
      Reviewable
        .default_visible
        .pending
        .group(:reviewable_by_moderator, :reviewable_by_group_id)
        .pluck(:reviewable_by_moderator, :reviewable_by_group_id, "count(*)")
        .each do |reviewable_by_moderator, reviewable_by_group_id, count|
          counts[:admins] += count
          counts[:moderators] += count if reviewable_by_moderator
          counts[reviewable_by_group_id] += count if reviewable_by_group_id
        end

      notify_users(User.real.admins, all_updates[:admins])

      if reviewable.reviewable_by_moderator?
        notify_users(
          User.real.moderators.where("id NOT IN (?)", @contacted),
          all_updates[:moderators],
        )
      end

      if SiteSetting.enable_category_group_moderation? && (group = reviewable.reviewable_by_group)
        users = group.users.includes(:group_users).where("users.id NOT IN (?)", @contacted)

        users.find_each do |user|
          count = 0
          updates = {}
          user.group_users.each do |gu|
            updates.merge!(all_updates[gu.group_id])
            count += counts[gu.group_id]
          end

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
