class Group < ActiveRecord::Base
  has_many :category_groups
  has_many :group_users

  has_many :categories, through: :category_groups
  has_many :users, through: :group_users

  def self.builtin
    Enum.new(:moderators, :admins, :trust_level_1, :trust_level_2)
  end

  def add(user)
    self.users.push(user)
  end
end
