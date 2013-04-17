class Group < ActiveRecord::Base
  def self.builtin
    Enum.new(:moderators, :admins, :trust_level_1, :trust_level_2)
  end
end
