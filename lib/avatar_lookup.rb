class AvatarLookup

  def initialize(user_ids=[])
    @user_ids = user_ids.tap(&:compact!).tap(&:uniq!).tap(&:flatten!)
  end

  # Lookup a user by id
  def [](user_id)
    users[user_id]
  end

  private

  def users
    @users ||= user_lookup_hash
  end

  LOOKUP_COLUMNS ||= [:id, :email, :username, :uploaded_avatar_id]

  def user_lookup_hash
    hash = {}
    User.where(id: @user_ids)
        .includes(:user_avatar)
        .select(LOOKUP_COLUMNS)
        .each{ |user| hash[user.id] = user }
    hash
  end
end
