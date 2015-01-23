module Jobs

  class UpdateGravatar < Jobs::Base

    def execute(args)
      @user = User.find_by(id: args[:user_id])
      @avatar = @user.user_avatar.gravatar_upload_id

      return unless @user && @avatar

      avatar.update_gravatar!

      return if is_using_custom_uploaded_avatar || is_using_custom_uploaded_avatar
      if @avatar.gravatar_upload_id
        user.update_column(:uploaded_avatar_id, avatar.gravatar_upload_id)
      end
    end

    private

    def is_using_system_avatar
      @user.uploaded_avatar_id == nil
    end

    def is_using_custom_uploaded_avatar
      @user.uploaded_avatar_id == @avatar.custom_upload_id
    end
  end

end
