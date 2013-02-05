class AvatarLookup

  def initialize(user_ids)
    @user_ids = user_ids

    @user_ids.flatten!
    @user_ids.compact! if @user_ids.present?
    @user_ids.uniq! if @user_ids.present?

    @loaded = false
  end

  # Lookup a user by id
  def [](user_id)
    ensure_loaded!
    @users_hashed[user_id]
  end


  protected

    def ensure_loaded!
      return if @loaded

      @users_hashed = {}
      # need email for hash
      User.where(id: @user_ids).select([:id, :email, :email, :username]).each do |u|
        @users_hashed[u.id] = u
      end

      @loaded = true
    end


end
