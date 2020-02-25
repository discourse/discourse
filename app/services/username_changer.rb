# frozen_string_literal: true

class UsernameChanger

  def initialize(user, new_username, actor = nil)
    @user = user
    @old_username = user.username
    @new_username = new_username
    @actor = actor
  end

  def self.change(user, new_username, actor = nil)
    self.new(user, new_username, actor).change
  end

  def change(asynchronous: true, run_update_job: true)
    @user.username = @new_username

    if @user.save
      if @actor && @old_username != @new_username
        StaffActionLogger.new(@actor).log_username_change(@user, @old_username, @new_username)
      end

      UsernameChanger.update_username(user_id: @user.id,
                                      old_username: @old_username,
                                      new_username: @new_username,
                                      avatar_template: @user.avatar_template,
                                      asynchronous: asynchronous) if run_update_job
      return true
    end

    false
  end

  def self.update_username(user_id:, old_username:, new_username:, avatar_template:, asynchronous: true)
    args = {
      user_id: user_id,
      old_username: old_username,
      new_username: new_username,
      avatar_template: avatar_template
    }

    if asynchronous
      Jobs.enqueue(:update_username, args)
    else
      Jobs::UpdateUsername.new.execute(args)
    end
  end
end
