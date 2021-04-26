# frozen_string_literal: true
class ThemeJavascriptsController < ApplicationController
  DISK_CACHE_PATH = "#{Rails.root}/tmp/javascript-cache"

  skip_before_action(
    :check_xhr,
    :handle_theme,
    :preload_json,
    :redirect_to_login_if_required,
    :verify_authenticity_token,
    only: [:show, :show_tests]
  )

  before_action :is_asset_path, :no_cookies, :apply_cdn_headers, only: [:show]

  def show
    raise Discourse::NotFound unless last_modified.present?
    return render body: nil, status: 304 if not_modified?

    # Security: safe due to route constraint
    cache_file = "#{DISK_CACHE_PATH}/#{params[:digest]}.js"

    unless File.exist?(cache_file)
      content = query.pluck_first(:content)
      raise Discourse::NotFound if content.nil?

      FileUtils.mkdir_p(DISK_CACHE_PATH)
      File.write(cache_file, content)
    end

    # this is only required for NGINX X-SendFile it seems
    response.headers["Content-Length"] = File.size(cache_file).to_s
    set_cache_control_headers
    send_file(cache_file, disposition: :inline)
  end

  def show_tests
    raise Discourse::NotFound if Rails.env.production?

    theme_id = params.require(:theme_id)
    theme = Theme.find(theme_id)
    content = ThemeField
      .where(
        theme_id: theme_id,
        target_id: Theme.targets[:tests_js]
      )
      .each(&:ensure_baked!)
      .map(&:value_baked)
      .join("\n")

    ThemeJavascriptCompiler.force_default_settings(content, theme)

    response.headers["Content-Length"] = content.size.to_s
    response.headers["Last-Modified"] = Time.zone.now.httpdate
    immutable_for(1.second)

    send_data content, filename: "js-tests-theme-#{theme_id}.js", disposition: :inline
  end

  private

  def query
    @query ||= JavascriptCache.where(digest: params[:digest]).limit(1)
  end

  def last_modified
    @last_modified ||= query.pluck_first(:updated_at)
  end

  def not_modified?
    cache_time =
      begin
        Time.rfc2822(request.env["HTTP_IF_MODIFIED_SINCE"])
      rescue ArgumentError
        nil
      end

    cache_time && last_modified && last_modified <= cache_time
  end

  def set_cache_control_headers
    if Rails.env.development?
      response.headers['Last-Modified'] = Time.zone.now.httpdate
      immutable_for(1.second)
    else
      response.headers['Last-Modified'] = last_modified.httpdate if last_modified
      immutable_for(1.year)
    end
  end
end
