require_dependency 'distributed_memoizer'
require_dependency 'file_helper'

class StaticController < ApplicationController

  skip_before_filter :check_xhr, :redirect_to_login_if_required
  skip_before_filter :verify_authenticity_token, only: [:brotli_asset, :cdn_asset, :enter, :favicon]

  PAGES_WITH_EMAIL_PARAM = ['login', 'password_reset', 'signup']

  def show
    return redirect_to(path '/') if current_user && (params[:id] == 'login' || params[:id] == 'signup')
    return redirect_to path('/login') if SiteSetting.login_required? && current_user.nil? && (params[:id] == 'faq' || params[:id] == 'guidelines')

    map = {
      "faq" => {redirect: "faq_url", topic_id: "guidelines_topic_id"},
      "tos" => {redirect: "tos_url", topic_id: "tos_topic_id"},
      "privacy" => {redirect: "privacy_policy_url", topic_id: "privacy_topic_id"}
    }

    @page = params[:id]

    if map.has_key?(@page)
      site_setting_key = map[@page][:redirect]
      url = SiteSetting.send(site_setting_key)
      return redirect_to(url) unless url.blank?
    end

    # The /guidelines route ALWAYS shows our FAQ, ignoring the faq_url site setting.
    @page = 'faq' if @page == 'guidelines'

    # Don't allow paths like ".." or "/" or anything hacky like that
    @page.gsub!(/[^a-z0-9\_\-]/, '')

    if map.has_key?(@page)
      @topic = Topic.find_by_id(SiteSetting.send(map[@page][:topic_id]))
      raise Discourse::NotFound unless @topic
      @title = @topic.title
      @body = @topic.posts.first.cooked
      @faq_overriden = !SiteSetting.faq_url.blank?
      render :show, layout: !request.xhr?, formats: [:html]
      return
    end

    if I18n.exists?("static.#{@page}")
      render html: I18n.t("static.#{@page}"), layout: !request.xhr?, formats: [:html]
      return
    end

    if PAGES_WITH_EMAIL_PARAM.include?(@page) && params[:email]
      cookies[:email] = { value: params[:email], expires: 1.day.from_now }
    end

    file = "static/#{@page}.#{I18n.locale}"
    file = "static/#{@page}.en" if lookup_context.find_all("#{file}.html").empty?
    file = "static/#{@page}"    if lookup_context.find_all("#{file}.html").empty?

    if lookup_context.find_all("#{file}.html").any?
      render file, layout: !request.xhr?, formats: [:html]
      return
    end

    raise Discourse::NotFound
  end

  # This method just redirects to a given url.
  # It's used when an ajax login was successful but we want the browser to see
  # a post of a login form so that it offers to remember your password.
  def enter
    params.delete(:username)
    params.delete(:password)

    destination = path("/")

    if params[:redirect].present? && !params[:redirect].match(login_path)
      begin
        forum_uri = URI(Discourse.base_url)
        uri = URI(params[:redirect])

        if uri.path.present? &&
           (uri.host.blank? || uri.host == forum_uri.host) &&
           uri.path !~ /\./

          destination = uri.path
          destination = "#{uri.path}?#{uri.query}" if uri.path =~ /new-topic/ || uri.path =~ /new-message/ || uri.path =~ /user-api-key/
        end
      rescue URI::InvalidURIError
        # Do nothing if the URI is invalid
      end
    end

    redirect_to destination
  end

  # We need to be able to draw our favicon on a canvas
  # and pull it off the canvas into a data uri
  # This can work by ensuring people set all the right CORS
  # settings in the CDN asset, BUT its annoying and error prone
  # instead we cache the favicon in redis and serve it out real quick with
  # a huge expiry, we also cache these assets in nginx so it bypassed if needed
  def favicon

    data = DistributedMemoizer.memoize('favicon' + SiteSetting.favicon_url, 60*30) do
      begin
        file = FileHelper.download(SiteSetting.favicon_url, 50.kilobytes, "favicon.png", true)
        data = file.read
        file.unlink
        data
      rescue => e
        AdminDashboardData.add_problem_message('dashboard.bad_favicon_url', 1800)
        Rails.logger.debug("Invalid favicon_url #{SiteSetting.favicon_url}: #{e}\n#{e.backtrace}")
        ""
      end
    end

    if data.bytesize == 0
      @@default_favicon ||= File.read(Rails.root + "public/images/default-favicon.png")
      response.headers["Content-Length"] = @@default_favicon.bytesize.to_s
      render text: @@default_favicon, content_type: "image/png"
    else
      immutable_for 1.year
      response.headers["Expires"] = 1.year.from_now.httpdate
      response.headers["Content-Length"] = data.bytesize.to_s
      response.headers["Last-Modified"] = Time.new('2000-01-01').httpdate
      render text: data, content_type: "image/png"
    end
  end

  def brotli_asset
    serve_asset(".br") do
      response.headers["Content-Encoding"] = 'br'
    end
  end


  def cdn_asset
    serve_asset
  end

  protected

  def serve_asset(suffix=nil)

    path = File.expand_path(Rails.root + "public/assets/#{params[:path]}#{suffix}")

    # SECURITY what if path has /../
    raise Discourse::NotFound unless path.start_with?(Rails.root.to_s + "/public/assets")


    response.headers["Expires"] = 1.year.from_now.httpdate
    response.headers["Access-Control-Allow-Origin"] = params[:origin] if params[:origin]

    begin
      response.headers["Last-Modified"] = File.ctime(path).httpdate
    rescue Errno::ENOENT
      begin
        if GlobalSetting.fallback_assets_path.present?
          path = File.expand_path("#{GlobalSetting.fallback_assets_path}/#{params[:path]}#{suffix}")
          response.headers["Last-Modified"] = File.ctime(path).httpdate
        else
          raise
        end
      rescue Errno::ENOENT
        expires_in 1.second, public: true, must_revalidate: false

        render plain: "can not find #{params[:path]}", status: 404
        return
      end
    end

    response.headers["Content-Length"] = File.size(path).to_s

    yield if block_given?

    immutable_for 1.year

    # disable NGINX mucking with transfer
    request.env['sendfile.type'] = ''

    opts = { disposition: nil }
    opts[:type] = "application/javascript" if params[:path] =~ /\.js$/
    send_file(path, opts)

  end

end
