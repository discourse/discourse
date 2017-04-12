class StylesheetsController < ApplicationController
  skip_before_filter :preload_json, :redirect_to_login_if_required, :check_xhr, :verify_authenticity_token, only: [:show, :show_source_map]

  def show_source_map
    show_resource(source_map: true)
  end

  def show
    show_resource
  end

  protected

  def show_resource(source_map: false)

    extension = source_map ? ".css.map" : ".css"

    params[:name]

    no_cookies

    target,digest = params[:name].split(/_([a-f0-9]{40})/)

    if Rails.env == "development"
      # TODO add theme
      # calling this method ensures we have a cache for said target
      # we hold of re-compilation till someone asks for asset
      if target.include?("theme")
        split_target,theme_id = target.split(/_(-?[0-9]+)/)
        theme = Theme.find(theme_id) if theme_id
      else
        split_target,color_scheme_id = target.split(/_(-?[0-9]+)/)
        theme = Theme.find_by(color_scheme_id: color_scheme_id)
      end
      Stylesheet::Manager.stylesheet_link_tag(split_target, nil, theme&.key)
    end

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
    location = "#{Rails.root}/#{Stylesheet::Manager::CACHE_PATH}/#{target}#{underscore_digest}#{extension}"

    stylesheet_time = query.pluck(:created_at).first

    if !stylesheet_time
      handle_missing_cache(location, target, digest)
    end

    if cache_time && stylesheet_time && stylesheet_time <= cache_time
      return render nothing: true, status: 304
    end


    unless File.exist?(location)
      if current = query.limit(1).pluck(source_map ? :source_map : :content).first
        File.write(location, current)
      else
        raise Discourse::NotFound
      end
    end

    if Rails.env == "development"
      response.headers['Last-Modified'] = Time.zone.now.httpdate
      immutable_for(1.second)
    else
      response.headers['Last-Modified'] = stylesheet_time.httpdate if stylesheet_time
      immutable_for(1.year)
    end
    send_file(location, disposition: :inline)
  end

  def handle_missing_cache(location, name, digest)
    location = location.sub(".css.map", ".css")
    source_map_location = location + ".map"

    existing = File.read(location) rescue nil
    if existing && digest
      source_map = File.read(source_map_location) rescue nil
      StylesheetCache.add(name, digest, existing, source_map)
    end
  end

end

