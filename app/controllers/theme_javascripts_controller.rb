# frozen_string_literal: true
class ThemeJavascriptsController < ApplicationController
  DISK_CACHE_PATH = "#{Rails.root}/tmp/javascript-cache".freeze
  TESTS_DISK_CACHE_PATH = "#{Rails.root}/tmp/javascript-cache/tests".freeze

  skip_before_action(
    :check_xhr,
    :handle_theme,
    :preload_json,
    :redirect_to_login_if_required,
    :redirect_to_profile_if_required,
    :verify_authenticity_token,
    only: %i[show show_map show_tests],
  )

  before_action :is_asset_path, :no_cookies, :apply_cdn_headers, only: %i[show show_map show_tests]

  def show
    raise Discourse::NotFound if last_modified.blank?
    return render body: nil, status: 304 if not_modified?

    # Security: safe due to route constraint
    cache_file = "#{DISK_CACHE_PATH}/#{params[:digest]}.js"

    write_if_not_cached(cache_file) do
      content, has_source_map = query.pick(:content, "source_map IS NOT NULL")
      if has_source_map
        content +=
          "\n//# sourceMappingURL=#{params[:digest]}.map?__ws=#{Discourse.current_hostname}\n"
      end
      content
    end

    serve_file(cache_file)
  end

  def show_map
    raise Discourse::NotFound if last_modified.blank?
    return render body: nil, status: 304 if not_modified?

    # Security: safe due to route constraint
    cache_file = "#{DISK_CACHE_PATH}/#{params[:digest]}.map"

    write_if_not_cached(cache_file) { query.pick(:source_map) }

    serve_file(cache_file)
  end

  def show_tests
    digest = params[:digest]
    raise Discourse::NotFound if !digest.match?(/\A\h{40}\z/)

    theme = Theme.find_by(id: params[:theme_id])
    raise Discourse::NotFound if theme.blank?

    content, content_digest = theme.baked_js_tests_with_digest
    raise Discourse::NotFound if content.blank? || content_digest != digest

    @cache_file = "#{TESTS_DISK_CACHE_PATH}/#{digest}.js"
    return render body: nil, status: 304 if not_modified?

    write_if_not_cached(@cache_file) { content }

    serve_file @cache_file
  end

  private

  def query
    @query ||= JavascriptCache.where(digest: params[:digest]).limit(1)
  end

  def last_modified
    @last_modified ||=
      begin
        if params[:action].to_s == "show_tests"
          File.exist?(@cache_file) ? File.ctime(@cache_file) : nil
        else
          query.pick(:updated_at)
        end
      end
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
      response.headers["Last-Modified"] = Time.zone.now.httpdate
      immutable_for(1.second)
    else
      response.headers["Last-Modified"] = last_modified.httpdate if last_modified
      immutable_for(1.year)
    end
  end

  def write_if_not_cached(cache_file)
    unless File.exist?(cache_file)
      content = yield
      raise Discourse::NotFound if content.nil?

      FileUtils.mkdir_p(File.dirname(cache_file))
      File.write(cache_file, content)
    end
  end

  def serve_file(cache_file)
    # this is only required for NGINX X-SendFile it seems
    response.headers["Content-Length"] = File.size(cache_file).to_s
    set_cache_control_headers
    type = cache_file.end_with?(".map") ? "application/json" : "text/javascript"
    send_file(cache_file, type: type, disposition: :inline)
  end
end
