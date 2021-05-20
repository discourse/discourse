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

    remove_reviewable_ids = Hash.new { |h, k| h[k] = [] }

    if args[:remove_reviewable_ids].present?
      Reviewable.where(id: args[:remove_reviewable_ids]).each do |r|
        remove_reviewable_ids[:admins] << r.id
        remove_reviewable_ids[:moderators] << r.id if r.reviewable_by_moderator?
        remove_reviewable_ids[r.reviewable_by_group_id] << r.id if r.reviewable_by_group_id
      end
    end

    # admins
    notify(
      User.real.admins.pluck(:id),
      count: counts[:admins],
      removed_ids: remove_reviewable_ids[:admins],
      status: args[:status]
    )

    # moderators
    if reviewable.reviewable_by_moderator?
      notify(
        User.real.moderators.where("id NOT IN (?)", @contacted).pluck(:id),
        count: counts[:moderators],
        removed_ids: remove_reviewable_ids[:moderators],
        status: args[:status]
      )
    end

    # category moderators
    if SiteSetting.enable_category_group_moderation? && (group = reviewable.reviewable_by_group)
      group.users.includes(:group_users).where("users.id NOT IN (?)", @contacted).find_each do |user|
        count = user.group_users.map { |gu| counts[gu.group_id] }.sum
        removed_ids = user.group_users.map { |gu| remove_reviewable_ids[gu.group_id] }.flatten.uniq
        notify([user.id], count: count, removed_ids: removed_ids, status: args[:status])
      end
    end
  end

  protected

  def notify(user_ids, count:, removed_ids:, status:)
    return if user_ids.blank?

    data = { reviewable_count: count }
    if removed_ids.present?
      data[:remove_reviewable_ids] = removed_ids
      data[:status] = status
    end

    MessageBus.publish("/reviewable_counts", data, user_ids: user_ids)
    @contacted += user_ids
  end

end
