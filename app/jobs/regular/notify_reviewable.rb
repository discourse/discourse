# frozen_string_literal: true

class Jobs::NotifyReviewable < ::Jobs::Base
  # remove all the legacy stuff here when redesigned_user_menu_enabled is
  # removed
  def execute(args)
    return unless reviewable = Reviewable.find_by(id: args[:reviewable_id])

    @contacted = Set.new

    all_updates = Hash.new { |h, k| h[k] = {} }

    if args[:updated_reviewable_ids].present?
      Reviewable.where(id: args[:updated_reviewable_ids]).each do |r|
        payload = {
          last_performing_username: args[:performing_username],
          status: r.status
        }

        all_updates[:admins][r.id] = payload
        all_updates[:moderators][r.id] = payload if r.reviewable_by_moderator?
        all_updates[r.reviewable_by_group_id][r.id] = payload if r.reviewable_by_group_id
      end
    end

    counts = Hash.new(0)

    Reviewable.default_visible.pending.each do |r|
      counts[:admins] += 1
      counts[:moderators] += 1 if r.reviewable_by_moderator?
      counts[r.reviewable_by_group_id] += 1 if r.reviewable_by_group_id
    end

    redesigned_menu_enabled_user_ids = User.redesigned_user_menu_enabled_user_ids

    new_menu_admins = User.real.admins.where(id: redesigned_menu_enabled_user_ids)
    notify_users(new_menu_admins, all_updates[:admins])

    legacy_menu_admins = User.real.admins.where("id NOT IN (?)", @contacted).pluck(:id)
    notify_legacy(
      legacy_menu_admins,
      count: counts[:admins],
      updates: all_updates[:admins],
    )

    if reviewable.reviewable_by_moderator?
      new_menu_mods = User
        .real
        .moderators
        .where("id IN (?)", redesigned_menu_enabled_user_ids - @contacted.to_a)
      notify_users(new_menu_mods, all_updates[:moderators])

      legacy_menu_mods = User.real.moderators.where("id NOT IN (?)", @contacted).pluck(:id)
      notify_legacy(
        legacy_menu_mods,
        count: counts[:moderators],
        updates: all_updates[:moderators],
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
        if redesigned_menu_enabled_user_ids.include?(user.id)
          notify_user(user, updates)
        else
          notify_legacy([user.id], count: count, updates: updates)
        end
      end
      @contacted += users.pluck(:id)
    end
  end

  protected

  def notify_legacy(user_ids, count:, updates:)
    return if user_ids.blank?

    data = { reviewable_count: count }
    data[:updates] = updates if updates.present?

    MessageBus.publish("/reviewable_counts", data, user_ids: user_ids)
    @contacted += user_ids
  end

  def notify_users(users, updates)
    users.find_each { |user| notify_user(user, updates) }
    @contacted += users.pluck(:id)
  end

  def notify_user(user, updates)
    data = {
      reviewable_count: user.reviewable_count,
      unseen_reviewable_count: user.unseen_reviewable_count
    }
    data[:updates] = updates if updates.present?

    user.publish_reviewable_counts(data)
  end
end
