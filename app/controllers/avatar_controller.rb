require_dependency 'letter_avatar'
class AvatarController < ApplicationController

  skip_before_filter :check_xhr, :verify_authenticity_token

  def show
    username = params[:username].to_s
    raise Discourse::NotFound unless user = User.find_by(username_lower: username.downcase)

    size = params[:size].to_i
    if size > 1000 || size < 1
      raise Discourse::NotFound
    end

    image = nil
    version = params[:version].to_i

    raise Discourse::NotFound unless version > 0 && user_avatar = user.user_avatar

    upload = version if user_avatar.contains_upload?(version)
    upload ||= user.uploaded_avatar if user.uploaded_avatar_id == version

    if user.uploaded_avatar && !upload
      return redirect_to "/avatar/#{user.username_lower}/#{size}/#{user.uploaded_avatar_id}.png"
    elsif upload
      # TODO broken with S3 (should retrun a permanent redirect)
      original = Discourse.store.path_for(user.uploaded_avatar)
      if File.exists?(original)
        optimized = OptimizedImage.create_for(
          user.uploaded_avatar,
          size,
          size,
          allow_animation: SiteSetting.allow_animated_avatars
        )
        image = Discourse.store.path_for(optimized)
      end
    end

    if image
      expires_in 1.year, public: true
      send_file image, disposition: nil
    else
      raise Discourse::NotFound
    end
  end
end
