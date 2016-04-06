class UserFirst < ActiveRecord::Base

  def self.types
    @types ||= Enum.new(used_emoji: 1,
                        mentioned_user: 2 #unused now
                       )
  end

  def self.create_for(user_id, type, post_id=nil)
    # the usual case will be that it is already in table, don't try to insert
    return false if UserFirst.exists?(user_id: user_id, first_type: types[type])

    create!(user_id: user_id, first_type: types[type], post_id: post_id)
    true
  rescue PG::UniqueViolation, ActiveRecord::RecordNotUnique
    # Violating the index just means the user already did it
    false
  end
end
