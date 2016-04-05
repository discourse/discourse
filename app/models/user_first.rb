class UserFirst < ActiveRecord::Base

  def self.types
    @types ||= Enum.new(used_emoji: 1, mentioned_user: 2)
  end

  def self.create_for(user_id, type, post_id=nil)
    create!(user_id: user_id, first_type: types[type], post_id: post_id)
    true
  rescue PG::UniqueViolation, ActiveRecord::RecordNotUnique
    # Violating the index just means the user already did it
    false
  end
end
