require_dependency 'distributed_memoizer'
require_dependency 'file_helper'

class StaticController < ApplicationController

  skip_before_action :check_xhr, :redirect_to_login_if_required
  skip_before_action :verify_authenticity_token, only: [:brotli_asset, :cdn_asset, :enter, :favicon, :service_worker_asset]
  skip_before_action :preload_json, only: [:brotli_asset, :cdn_asset, :enter, :favicon, :service_worker_asset]
  skip_before_action :handle_theme, only: [:brotli_asset, :cdn_asset, :enter, :favicon, :service_worker_asset]

  PAGES_WITH_EMAIL_PARAM = ['login', 'password_reset', 'signup']

  def show
    return redirect_to(path '/') if current_user && (params[:id] == 'login' || params[:id] == 'signup')
    if SiteSetting.login_required? && current_user.nil? && ['faq', 'guidelines'].include?(params[:id])
      return redirect_to path('/login')
    end

    map = {
      "faq" => { redirect: "faq_url", topic_id: "guidelines_topic_id" },
      "tos" => { redirect: "tos_url", topic_id: "tos_topic_id" },
      "privacy" => { redirect: "privacy_policy_url", topic_id: "privacy_topic_id" }
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
      title_prefix = if I18n.exists?("js.#{@page}")
        I18n.t("js.#{@page}")
      else
        @topic.title
      end
      @title = "#{title_prefix} - #{SiteSetting.title}"
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
      rescue URI::Error
        # Do nothing if the URI is invalid
      end
    end

    redirect_to destination
  end

  FAVICON ||= -"favicon"

  # We need to be able to draw our favicon on a canvas, this happens when you enable the feature
  # that draws the notification count on top of favicon (per user default off)
  #
  # With s3 the original upload is going to be stored at s3, we don't have a local copy of the favicon.
  # To allow canvas to work with s3 we are going to need to add special CORS headers and use
  # a special crossorigin hint on the original, this is not easily workable.
  #
  # Forcing all consumers to set magic CORS headers on a CDN is also not workable for us.
  #
  # So we cache the favicon in redis and serve it out real quick with
  # a huge expiry, we also cache these assets in nginx so it is bypassed if needed
  def favicon
    is_asset_path

    hijack do
      data = DistributedMemoizer.memoize(FAVICON + SiteSetting.site_favicon_url, 60 * 30) do
        begin
          file = FileHelper.download(
            UrlHelper.absolute(SiteSetting.site_favicon_url),
            max_file_size: 50.kilobytes,
            tmp_file_name: FAVICON,
            follow_redirect: true
          )
          file ||= Tempfile.new([FAVICON, ".png"])
          data = file.read
          file.unlink
          data
        rescue => e
          AdminDashboardData.add_problem_message('dashboard.bad_favicon_url', 1800)
          Rails.logger.debug("Invalid favicon_url #{SiteSetting.site_favicon_url}: #{e}\n#{e.backtrace}")
          ""
        end
      end

      if data.bytesize == 0
        @@default_favicon ||= File.read(Rails.root + "public/images/default-favicon.png")
        response.headers["Content-Length"] = @@default_favicon.bytesize.to_s
        render body: @@default_favicon, content_type: "image/png"
      else
        immutable_for 1.year
        response.headers["Expires"] = 1.year.from_now.httpdate
        response.headers["Content-Length"] = data.bytesize.to_s
        response.headers["Last-Modified"] = Time.new('2000-01-01').httpdate
        render body: data, content_type: "image/png"
      end
    end
  end

  def brotli_asset
    is_asset_path

    serve_asset(".br") do
      response.headers["Content-Encoding"] = 'br'
    end
  end

  def cdn_asset
    is_asset_path

    serve_asset
  end

  def service_worker_asset
    is_asset_path

    respond_to do |format|
      format.js do
        # https://github.com/w3c/ServiceWorker/blob/master/explainer.md#updating-a-service-worker
        # Maximum cache that the service worker will respect is 24 hours.
        # However, ensure that these may be cached and served for longer on servers.
        immutable_for 1.year

        if Rails.application.assets_manifest.assets['service-worker.js']
          path = File.expand_path(Rails.root + "public/assets/#{Rails.application.assets_manifest.assets['service-worker.js']}")
          response.headers["Last-Modified"] = File.ctime(path).httpdate
        end
        render(
          plain: Rails.application.assets_manifest.find_sources('service-worker.js').first,
          content_type: 'application/javascript'
        )
      end
    end
  end

  protected

  def serve_asset(suffix = nil)

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
