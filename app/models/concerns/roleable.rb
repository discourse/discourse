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
        whispers_allowed_group_ids = SiteSetting.whispers_allowed_group_ids
        return false if whispers_allowed_group_ids.blank?
        return true if admin
        return true if whispers_allowed_group_ids.include?(primary_group_id)
        group_users&.exists?(group_id: whispers_allowed_group_ids)
      end
  end

  def grant_moderation!
    return if moderator
    set_permission("moderator", true)
    auto_approve_user
    enqueue_staff_welcome_message(:moderator)
    set_default_notification_levels(:moderators)
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
end
