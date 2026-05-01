# frozen_string_literal: true

module Roleable
  extend ActiveSupport::Concern

  included do
    scope :admins, -> { where(admin: true) }
    scope :moderators, -> { where(moderator: true) }
    scope :staff, -> { where("moderator or admin ") }
  end

  # any user that is either a moderator or an admin
  def staff?
    admin || moderator
  end

  def regular?
    !staff?
  end

  def whisperer?
    @whisperer ||=
      begin
        return false if SiteSetting.whispers_allowed_groups_map.empty?
        return true if admin
        return true if SiteSetting.whispers_allowed_groups_map.include?(primary_group_id)
        group_users&.exists?(group_id: SiteSetting.whispers_allowed_groups_map)
      end
  end

  def grant_moderation!
    return if moderator
    set_permission("moderator", true)
    auto_approve_user
    enqueue_staff_welcome_message(:moderator)
    set_default_notification_levels(:moderators)
    mark_upcoming_changes_seen_on_new_site!
  end

  def revoke_moderation!
    set_permission("moderator", false)
  end

  def grant_admin!
    return if admin
    set_permission("admin", true)
    auto_approve_user
    enqueue_staff_welcome_message(:admin)
    set_default_notification_levels(:admins)
    mark_upcoming_changes_seen_on_new_site!
  end

  def revoke_admin!
    set_permission("admin", false)
  end

  def save_and_refresh_staff_groups!
    transaction do
      self.save!
      Group.refresh_automatic_groups!(:admins, :moderators, :staff)
    end
  end

  def set_permission(permission_name, value)
    self.public_send("#{permission_name}=", value)
    save_and_refresh_staff_groups!
  end

  def set_default_notification_levels(group_name)
    Group.set_category_and_tag_default_notification_levels!(self, group_name)
    if group_name == :admins || group_name == :moderators
      Group.set_category_and_tag_default_notification_levels!(self, :staff)
    end
  end

  def reload(options = nil)
    @whisperer = nil
    super(options)
  end

  private

  def auto_approve_user
    if reviewable = ReviewableUser.pending.find_by(target: self)
      reviewable.perform(Discourse.system_user, :approve_user, send_email: false)
    else
      ReviewableUser.set_approved_fields!(self, Discourse.system_user)
      self.save!
    end
  end

  # To avoid showing a blue dot for upcoming changes in the
  # admin UI, since we make UpcomingChangeEvent.added entries
  # for the site when we run Jobs::CheckUpcomingChanges for
  # the first time. We don't need to notify admins so early
  # about old upcoming changes.
  def mark_upcoming_changes_seen_on_new_site!
    return unless Migration::Helpers.new_site?
    return if custom_fields["last_visited_upcoming_changes_at"].present?
    custom_fields["last_visited_upcoming_changes_at"] = (
      Migration::Helpers.site_created_at + 1.hour
    ).iso8601
    save_custom_fields
  end
end
