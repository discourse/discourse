require_dependency 'letter_avatar'

class UserAvatarsController < ApplicationController

  skip_before_action :preload_json, :redirect_to_login_if_required, :check_xhr, :verify_authenticity_token, only: [:show, :show_letter, :show_proxy_letter]

  def refresh_gravatar
    user = User.find_by(username_lower: params[:username].downcase)
    guardian.ensure_can_edit!(user)

    if user
      hijack do
        user.create_user_avatar(user_id: user.id) unless user.user_avatar
        user.user_avatar.update_gravatar!

        gravatar = if user.user_avatar.gravatar_upload_id
          {
            gravatar_upload_id: user.user_avatar.gravatar_upload_id,
            gravatar_avatar_template: User.avatar_template(user.username, user.user_avatar.gravatar_upload_id)
          }
        else
          {
            gravatar_upload_id: nil,
            gravatar_avatar_template: nil
          }
        end

        render json: gravatar
      end
    else
      raise Discourse::NotFound
    end
  end

  def show_proxy_letter
    is_asset_path

    if SiteSetting.external_system_avatars_url !~ /^\/letter_avatar_proxy/
      raise Discourse::NotFound
    end

    params.require(:letter)
    params.require(:color)
    params.require(:version)
    params.require(:size)

    hijack do
      identity = LetterAvatar::Identity.new
      identity.letter = params[:letter].to_s[0].upcase
      identity.color = params[:color].scan(/../).map(&:hex)
      image = LetterAvatar.generate(params[:letter].to_s, params[:size].to_i, identity: identity)

      response.headers["Last-Modified"] = File.ctime(image).httpdate
      response.headers["Content-Length"] = File.size(image).to_s
      immutable_for(1.year)
      send_file image, disposition: nil
    end
  end

  def show_letter
    is_asset_path

    params.require(:username)
    params.require(:version)
    params.require(:size)

    no_cookies

    return render_blank if params[:version] != LetterAvatar.version

    hijack do
      image = LetterAvatar.generate(params[:username].to_s, params[:size].to_i)

      response.headers["Last-Modified"] = File.ctime(image).httpdate
      response.headers["Content-Length"] = File.size(image).to_s
      immutable_for(1.year)
      send_file image, disposition: nil
    end
  end

  def show
    is_asset_path

    # we need multisite support to keep a single origin pull for CDNs
    RailsMultisite::ConnectionManagement.with_hostname(params[:hostname]) do
      hijack do
        show_in_site(params[:hostname])
      end
    end
  end

  protected

  def show_in_site(hostname)

    username = params[:username].to_s
    return render_blank unless user = User.find_by(username_lower: username.downcase)

    upload_id, version = params[:version].split("_")

    version = (version || OptimizedImage::VERSION).to_i
    return render_blank if version != OptimizedImage::VERSION

    upload_id = upload_id.to_i
    return render_blank unless upload_id > 0

    size = params[:size].to_i
    return render_blank if size < 8 || size > 1000

    if !Discourse.avatar_sizes.include?(size) && Discourse.store.external?
      closest = Discourse.avatar_sizes.to_a.min { |a, b| (size - a).abs <=> (size - b).abs }
      avatar_url = UserAvatar.local_avatar_url(hostname, user.username_lower, upload_id, closest)
      return redirect_to cdn_path(avatar_url)
    end

    upload = Upload.find_by(id: upload_id) if user&.user_avatar&.contains_upload?(upload_id)
    upload ||= user.uploaded_avatar if user.uploaded_avatar_id == upload_id

    if user.uploaded_avatar && !upload
      avatar_url = UserAvatar.local_avatar_url(hostname, user.username_lower, user.uploaded_avatar_id, size)
      return redirect_to cdn_path(avatar_url)
    elsif upload && optimized = get_optimized_image(upload, size)
      if optimized.local?
        optimized_path = Discourse.store.path_for(optimized)
        image = optimized_path if File.exists?(optimized_path)
      else
        return proxy_avatar(Discourse.store.cdn_url(optimized.url))
      end
    end

    if image
      response.headers["Last-Modified"] = File.ctime(image).httpdate
      response.headers["Content-Length"] = File.size(image).to_s
      immutable_for 1.year
      send_file image, disposition: nil
    else
      render_blank
    end
  rescue OpenURI::HTTPError
    render_blank
  end

  PROXY_PATH = Rails.root + "tmp/avatar_proxy"
  def proxy_avatar(url)

    if url[0..1] == "//"
      url = (SiteSetting.force_https ? "https:" : "http:") + url
    end

    sha = Digest::SHA1.hexdigest(url)
    filename = "#{sha}#{File.extname(url)}"
    path = "#{PROXY_PATH}/#{filename}"

    unless File.exist? path
      FileUtils.mkdir_p PROXY_PATH
      tmp = FileHelper.download(
        url,
        max_file_size: 1.megabyte,
        tmp_file_name: filename,
        follow_redirect: true,
        read_timeout: 10
      )
      FileUtils.mv tmp.path, path
    end

    # putting a bogus date cause download is not retaining the data
    response.headers["Last-Modified"] = DateTime.parse("1-1-2000").httpdate
    response.headers["Content-Length"] = File.size(path).to_s
    immutable_for(1.year)
    send_file path, disposition: nil
  end

  # this protects us from a DoS
  def render_blank
    path = Rails.root + "public/images/avatar.png"
    expires_in 10.minutes, public: true
    response.headers["Last-Modified"] = DateTime.parse("1-1-2000").httpdate
    response.headers["Content-Length"] = File.size(path).to_s
    send_file path, disposition: nil
  end

  def get_optimized_image(upload, size)
    OptimizedImage.create_for(
      upload,
      size,
      size,
      filename: upload.original_filename,
      allow_animation: SiteSetting.allow_animated_avatars,
    )
  end

end
