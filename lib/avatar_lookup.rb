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
    @users ||= User.where(:id => @user_ids)
                   .select([:id, :email, :username, :use_uploaded_avatar, :uploaded_avatar_template, :uploaded_avatar_id])
                   .inject({}) do |hash, user|
      hash.merge({user.id => user})
    end
  end
end
