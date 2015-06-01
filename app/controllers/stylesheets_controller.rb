class StylesheetsController < ApplicationController
  skip_before_filter :preload_json, :redirect_to_login_if_required, :check_xhr, :verify_authenticity_token, only: [:show]

  def show

    no_cookies

    target,digest = params[:name].split(/_([a-f0-9]{40})/)

    cache_time = request.env["HTTP_IF_MODIFIED_SINCE"]
    cache_time = Time.rfc2822(cache_time) rescue nil if cache_time

    query = StylesheetCache.where(target: target)
    if digest
      query = query.where(digest: digest)
    else
      query = query.order('id desc')
    end

    # Security note, safe due to route constraint
    underscore_digest = digest ? "_" + digest : ""
    location = "#{Rails.root}/#{DiscourseStylesheets::CACHE_PATH}/#{target}#{underscore_digest}.css"

    stylesheet_time = query.pluck(:created_at).first

    if !stylesheet_time
      handle_missing_cache(location, target, digest)
    end

    if cache_time && stylesheet_time && stylesheet_time <= cache_time
      return render nothing: true, status: 304
    end


    unless File.exist?(location)
      if current = query.first
        File.write(location, current.content)
      else
        raise Discourse::NotFound
      end
    end

    response.headers['Last-Modified'] = stylesheet_time.httpdate if stylesheet_time
    expires_in 1.year, public: true unless Rails.env == "development"
    send_file(location, disposition: :inline)
  end

  protected

  def handle_missing_cache(location, name, digest)
    existing = File.read(location) rescue nil
    if existing && digest
      StylesheetCache.add(name, digest, existing)
    end
  end

end

