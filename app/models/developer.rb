require_dependency 'distributed_cache'

class Developer < ActiveRecord::Base
  belongs_to :user

  after_save :rebuild_cache
  after_destroy :rebuild_cache

  @id_cache = DistributedCache.new('developer_ids')

  def self.user_ids
    @id_cache["ids"] || rebuild_cache
  end

  def self.rebuild_cache
    @id_cache["ids"] = Set.new(Developer.pluck(:user_id))
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
