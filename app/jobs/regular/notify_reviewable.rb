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

    # admins
    notify(counts[:admins], User.real.admins.pluck(:id))

    # moderators
    if reviewable.reviewable_by_moderator?
      notify(counts[:moderators], User.real.moderators.where("id NOT IN (?)", @contacted).pluck(:id))
    end

    # category moderators
    if SiteSetting.enable_category_group_moderation? && (group = reviewable.reviewable_by_group)
      group.users.includes(:group_users).where("users.id NOT IN (?)", @contacted).find_each do |user|
        count = user.group_users.map { |gu| counts[gu.group_id] }.sum
        notify(count, [user.id])
      end
    end
  end

  protected

  def notify(count, user_ids)
    return if user_ids.blank?
    data = { reviewable_count: count }
    MessageBus.publish("/reviewable_counts", data, user_ids: user_ids)
    @contacted += user_ids
  end

end
