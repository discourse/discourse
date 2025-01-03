# frozen_string_literal: true

class StaticController < ApplicationController
  skip_before_action :check_xhr, :redirect_to_login_if_required, :redirect_to_profile_if_required
  skip_before_action :verify_authenticity_token,
                     only: %i[cdn_asset enter favicon service_worker_asset]
  skip_before_action :handle_theme, only: %i[cdn_asset enter favicon service_worker_asset]

  before_action :apply_cdn_headers, only: %i[cdn_asset enter favicon service_worker_asset]

  PAGES_WITH_EMAIL_PARAM = %w[login password_reset signup]
  MODAL_PAGES = %w[password_reset signup]
  DEFAULT_PAGES = {
    "faq" => {
      redirect: "faq_url",
      topic_id: "guidelines_topic_id",
    },
    "tos" => {
      redirect: "tos_url",
      topic_id: "tos_topic_id",
    },
    "privacy" => {
      redirect: "privacy_policy_url",
      topic_id: "privacy_topic_id",
    },
  }
  CUSTOM_PAGES = {} # Add via `#add_topic_static_page` in plugin API

  def show
    if current_user && (params[:id] == "login" || params[:id] == "signup")
      return redirect_to(path "/")
    end

    if SiteSetting.login_required? && current_user.nil? && %w[faq guidelines].include?(params[:id])
      return redirect_to path("/login")
    end

    rename_faq = SiteSetting.experimental_rename_faq_to_guidelines

    if rename_faq
      redirect_paths = %w[/rules /conduct]
      redirect_paths << "/faq" if SiteSetting.faq_url.blank?
      return redirect_to(path("/guidelines")) if redirect_paths.include?(request.path)
    end

    map = DEFAULT_PAGES.deep_merge(CUSTOM_PAGES)
    @page = params[:id]

    if map.has_key?(@page)
      site_setting_key = map[@page][:redirect]
      url = SiteSetting.get(site_setting_key) if site_setting_key
      return redirect_to(url, allow_other_host: true) if url.present?
    end

    # The /guidelines route ALWAYS shows our FAQ, ignoring the faq_url site setting.
    @page = "faq" if @page == "guidelines"

    # Don't allow paths like ".." or "/" or anything hacky like that
    @page = @page.gsub(/[^a-z0-9\_\-]/, "")

    if map.has_key?(@page)
      topic_id = map[@page][:topic_id]
      topic_id = instance_exec(&topic_id) if topic_id.is_a?(Proc)

      @topic = Topic.find_by_id(SiteSetting.get(topic_id))
      raise Discourse::NotFound unless @topic

      page_name =
        if @page == "faq"
          rename_faq ? "guidelines" : "faq"
        else
          @page
        end

      title_prefix =
        if I18n.exists?("js.#{page_name}")
          I18n.t("js.#{page_name}")
        else
          @topic.title
        end
      @title = "#{title_prefix} - #{SiteSetting.title}"
      @body = @topic.posts.first.cooked
      @faq_overridden = !SiteSetting.faq_url.blank?
      @experimental_rename_faq_to_guidelines = rename_faq

      render :show, layout: !request.xhr?, formats: [:html]
      return
    end

    @title = SiteSetting.title.dup

    if SiteSetting.short_site_description.present?
      @title << " - #{SiteSetting.short_site_description}"
    end

    if I18n.exists?("static.#{@page}")
      render html: I18n.t("static.#{@page}"), layout: !request.xhr?, formats: [:html]
      return
    end

    if PAGES_WITH_EMAIL_PARAM.include?(@page) && params[:email]
      cookies[:email] = { value: params[:email], expires: 1.day.from_now }
    end

    if lookup_context.find_all("static/#{@page}").any?
      render "static/#{@page}", layout: !request.xhr?, formats: [:html]
      return
    end

    if MODAL_PAGES.include?(@page)
      render html: nil, layout: true
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

    redirect_location = params[:redirect]
    if redirect_location.present? && !redirect_location.is_a?(String)
      raise Discourse::InvalidParameters.new(:redirect)
    elsif redirect_location.present? &&
          begin
            forum_uri = URI(Discourse.base_url)
            uri = URI(redirect_location)

            if uri.path.present? && !uri.path.starts_with?(login_path) &&
                 (uri.host.blank? || uri.host == forum_uri.host) &&
                 uri.path =~ %r{\A\/{1}[^\.\s]*\z}
              destination = "#{uri.path}#{uri.query ? "?#{uri.query}" : ""}"
            end
          rescue URI::Error
            # Do nothing if the URI is invalid
          end
    end

    redirect_to(destination, allow_other_host: false)
  end

  FAVICON = -"favicon"

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
      data =
        DistributedMemoizer.memoize("FAVICON#{SiteIconManager.favicon_url}", 60 * 30) do
          favicon = SiteIconManager.favicon
          next "" unless favicon

          if Discourse.store.external?
            begin
              file =
                FileHelper.download(
                  Discourse.store.cdn_url(favicon.url),
                  max_file_size: favicon.filesize,
                  tmp_file_name: FAVICON,
                  follow_redirect: true,
                )

              file&.read || ""
            rescue => e
              ProblemCheckTracker[:bad_favicon_url].problem!
              Rails.logger.debug("Failed to fetch favicon #{favicon.url}: #{e}\n#{e.backtrace}")
              ""
            ensure
              file&.unlink
            end
          else
            File.read(Rails.root.join("public", favicon.url[1..-1]))
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
        response.headers["Last-Modified"] = Time.new(2000, 01, 01).httpdate
        render body: data, content_type: "image/png"
      end
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

        if Rails.application.assets_manifest.assets["service-worker.js"]
          path =
            File.expand_path(
              Rails.root +
                "public/assets/#{Rails.application.assets_manifest.assets["service-worker.js"]}",
            )
          response.headers["Last-Modified"] = File.ctime(path).httpdate
        end
        content = Rails.application.assets_manifest.find_sources("service-worker.js").first

        base_url = File.dirname(helpers.script_asset_path("service-worker"))
        content =
          content.sub(%r{^//# sourceMappingURL=(service-worker-.+\.map)$}) do
            "//# sourceMappingURL=#{base_url}/#{Regexp.last_match(1)}"
          end
        render(plain: content, content_type: "application/javascript")
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
    request.env["sendfile.type"] = ""

    opts = { disposition: nil }
    opts[:type] = "application/javascript" if params[:path] =~ /\.js$/
    send_file(path, opts)
  end
end
