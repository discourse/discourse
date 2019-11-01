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

  def grant_moderation!
    set_permission('moderator', true)
    enqueue_welcome_moderator_message
  end

  def revoke_moderation!
    set_permission('moderator', false)
  end

  def grant_admin!
    set_permission('admin', true)
  end

  def revoke_admin!
    set_permission('admin', false)
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

end
