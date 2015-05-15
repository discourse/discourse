class UsernameChanger

  def initialize(user, new_username, actor=nil)
    @user = user
    @new_username = new_username
    @actor = actor
  end

  def self.change(user, new_username, actor=nil)
    self.new(user, new_username, actor).change
  end

  def change
    if @actor && @actor != @user
      StaffActionLogger.new(@actor).log_username_change(@user, @user.username, @new_username)
    end

    # future work: update mentions and quotes

    @user.username = @new_username
    @user.save
  end
end
