class AvatarLookup
  attr_accessor :user_ids, :users

  def initialize(user_ids=[])
    self.user_ids = AvatarLookup.filtered_users(user_ids)
  end

  # Lookup a user by id
  def [](user_id)
    self.users = AvatarLookup.hashed_users(user_ids) if self.users.nil?
    self.users[user_id]
  end

  private
  def self.filtered_users(user_ids=[])
    user_ids.flatten.tap(&:compact!).tap(&:uniq!)
  end

  def self.hashed_users(user_ids=[])
    users = User.where(:id => user_ids).select([:id, :email, :username])
    users_with_ids = users.collect {|x| [x.id, x] }.flatten
    Hash[*users_with_ids]
  end
end
