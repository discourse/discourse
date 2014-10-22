require_dependency 'letter_avatar'

class UserAvatarsController < ApplicationController
  DOT = Base64.decode64("R0lGODlhAQABALMAAAAAAIAAAACAAICAAAAAgIAAgACAgMDAwICAgP8AAAD/AP//AAAA//8A/wD//wBiZCH5BAEAAA8ALAAAAAABAAEAAAQC8EUAOw==")

  skip_before_filter :redirect_to_login_if_required, :check_xhr, :verify_authenticity_token, only: [:show, :show_letter]

  def refresh_gravatar
    user = User.find_by(username_lower: params[:username].downcase)
    guardian.ensure_can_edit!(user)

    if user
      user.create_user_avatar(user_id: user.id) unless user.user_avatar
      user.user_avatar.update_gravatar!

      render json: {upload_id: user.user_avatar.gravatar_upload_id}
    else
      raise Discourse::NotFound
    end
  end

  def show_letter
    params.require(:username)
    params.require(:version)
    params.require(:size)

    return render_dot if params[:version].to_i > LetterAvatar::VERSION

    image = LetterAvatar.generate(params[:username].to_s, params[:size].to_i)

    response.headers["Last-Modified"] = File.ctime(image).httpdate
    response.headers["Content-Length"] = File.size(image).to_s
    expires_in 1.year, public: true
    send_file image, disposition: nil
  end

  def show
    # we need multisite support to keep a single origin pull for CDNs
    RailsMultisite::ConnectionManagement.with_hostname(params[:hostname]) do
      show_in_site(RailsMultisite::ConnectionManagement.current_hostname)
    end
  end

  protected

  def show_in_site(hostname)
    username = params[:username].to_s
    return render_dot unless user = User.find_by(username_lower: username.downcase)

    size = params[:size].to_i
    return render_dot if size > 1000 || size < 1

    image = nil
    version = params[:version].to_i
    return render_dot unless version > 0 && user_avatar = user.user_avatar

    upload = Upload.find_by(id: version) if user_avatar.contains_upload?(version)
    upload ||= user.uploaded_avatar if user.uploaded_avatar_id == version

    if user.uploaded_avatar && !upload
      return redirect_to "/user_avatar/#{hostname}/#{user.username_lower}/#{size}/#{user.uploaded_avatar_id}.png"
    elsif upload
      original = Discourse.store.path_for(upload)
      if Discourse.store.external? || File.exists?(original)
        optimized = get_optimized_image(upload, size)

        if optimized
          if Discourse.store.external?
            expires_in 1.day, public: true
            return redirect_to optimized.url
          end

          image = Discourse.store.path_for(optimized)
        end
      end
    end

    if image
      response.headers["Last-Modified"] = File.ctime(image).httpdate
      response.headers["Content-Length"] = File.size(image).to_s
      expires_in 1.year, public: true
      send_file image, disposition: nil
    else
      render_dot
    end
  end

  # this protects us from a DoS
  def render_dot
    expires_in 10.minutes, public: true
    render text: DOT, content_type: "image/png"
  end

  def get_optimized_image(upload, size)
    OptimizedImage.create_for(
      upload,
      size,
      size,
      allow_animation: SiteSetting.allow_animated_avatars
    )
  end

end
