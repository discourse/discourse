# frozen_string_literal: true

class Developer < ActiveRecord::Base
  belongs_to :user

  after_destroy :rebuild_cache
  after_save :rebuild_cache

  def self.configured_email?(value)
    Rails.configuration.respond_to?(:developer_emails) &&
      Rails.configuration.developer_emails.include?(value&.strip&.downcase)
  end

  def self.id_cache
    @id_cache ||= DistributedCache.new("developer_ids")
  end

  def self.user_ids
    id_cache.defer_get_set("ids") { Set.new(Developer.pluck(:user_id)) }
  end

  def self.rebuild_cache
    id_cache.clear
  end

  def rebuild_cache
    Developer.rebuild_cache
  end
end

# == Schema Information
#
# Table name: developers
#
#  id      :integer          not null, primary key
#  user_id :integer          not null
#
# Indexes
#
#  index_developers_on_user_id  (user_id) UNIQUE
#
