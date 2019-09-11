# frozen_string_literal: true

require_dependency 'enum'

class NotificationType < ActiveRecord::Base
  # Types added before the notification_types table was added
  @old_types = {
    mentioned: 1,
    replied: 2,
    quoted: 3,
    edited: 4,
    liked: 5,
    private_message: 6,
    invited_to_private_message: 7,
    invitee_accepted: 8,
    posted: 9,
    moved_post: 10,
    linked: 11,
    granted_badge: 12,
    invited_to_topic: 13,
    custom: 14,
    group_mentioned: 15,
    group_message_summary: 16,
    watching_first_post: 17,
    topic_reminder: 18,
    liked_consolidated: 19,
    post_approved: 20,
    code_review_commit_approved: 21,
    membership_request_accepted: 22
  }

  @new_types = []

  class << self
    attr_reader :old_types
    attr_reader :new_types
  end

  # For use by plugins
  def self.add_notification_type(name)
    @new_types << name.to_sym
  end

  def self.enum
    @cache.getset(RailsMultisite::ConnectionManagement.current_db) do
      Enum.new(Hash[pluck(:name, :id)].symbolize_keys)
    end
  end

  def self.clear_cache!
    @cache = LruRedux::ThreadSafeCache.new(1000)
  end

  clear_cache!
end

# == Schema Information
#
# Table name: notification_types
#
#  id   :bigint           not null, primary key
#  name :string
#
# Indexes
#
#  index_notification_types_on_name  (name) UNIQUE
#
