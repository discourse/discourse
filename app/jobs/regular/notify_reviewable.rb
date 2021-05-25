# frozen_string_literal: true

class Jobs::NotifyReviewable < ::Jobs::Base

  def execute(args)
    return unless reviewable = Reviewable.find_by(id: args[:reviewable_id])

    @contacted = Set.new

    counts = Hash.new(0)

    Reviewable.default_visible.pending.each do |r|
      counts[:admins] += 1
      counts[:moderators] += 1 if r.reviewable_by_moderator?
      counts[r.reviewable_by_group_id] += 1 if r.reviewable_by_group_id
    end

    all_updates = Hash.new { |h, k| h[k] = {} }

    if args[:updated_reviewable_ids].present?
      Reviewable.where(id: args[:updated_reviewable_ids]).each do |r|
        payload = { status: r.status }

        all_updates[:admins][r.id] = payload
        all_updates[:moderators][r.id] = payload if r.reviewable_by_moderator?
        all_updates[r.reviewable_by_group_id][r.id] = payload if r.reviewable_by_group_id
      end
    end

    # admins
    notify(
      User.real.admins.pluck(:id),
      count: counts[:admins],
      updates: all_updates[:admins],
    )

    # moderators
    if reviewable.reviewable_by_moderator?
      notify(
        User.real.moderators.where("id NOT IN (?)", @contacted).pluck(:id),
        count: counts[:moderators],
        updates: all_updates[:moderators],
      )
    end

    # category moderators
    if SiteSetting.enable_category_group_moderation? && (group = reviewable.reviewable_by_group)
      group.users.includes(:group_users).where("users.id NOT IN (?)", @contacted).find_each do |user|
        count = 0
        updates = {}

        user.group_users.each do |gu|
          count += counts[gu.group_id] || 0
          updates.merge!(all_updates[gu.group_id] || {})
        end

        notify([user.id], count: count, updates: updates)
      end
    end
  end

  protected

  def notify(user_ids, count:, updates:)
    return if user_ids.blank?

    data = { reviewable_count: count }
    data[:updates] = updates if updates.present?

    MessageBus.publish("/reviewable_counts", data, user_ids: user_ids)
    @contacted += user_ids
  end

end
