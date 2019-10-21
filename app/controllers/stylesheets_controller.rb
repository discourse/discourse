# frozen_string_literal: true

class StylesheetsController < ApplicationController
  skip_before_action :preload_json, :redirect_to_login_if_required, :check_xhr, :verify_authenticity_token, only: [:show, :show_source_map]

  def show_source_map
    show_resource(source_map: true)
  end

  def show
    is_asset_path

    show_resource
  end

  protected

  def show_resource(source_map: false)

    extension = source_map ? ".css.map" : ".css"

    params[:name]

    no_cookies

    target, digest = params[:name].split(/_([a-f0-9]{40})/)

    if !Rails.env.production?
      # TODO add theme
      # calling this method ensures we have a cache for said target
      # we hold of re-compilation till someone asks for asset
      if target.include?("theme")
        split_target, theme_id = target.split(/_(-?[0-9]+)/)
        theme = Theme.find_by(id: theme_id) if theme_id.present?
      else
        split_target, color_scheme_id = target.split(/_(-?[0-9]+)/)
        theme = Theme.find_by(color_scheme_id: color_scheme_id)
      end
      Stylesheet::Manager.stylesheet_link_tag(split_target, nil, theme&.id)
    end

    cache_time = request.env["HTTP_IF_MODIFIED_SINCE"]

    if cache_time
      begin
        cache_time = Time.rfc2822(cache_time)
      rescue ArgumentError
      end
    end

    query = StylesheetCache.where(target: target)
    if digest
      query = query.where(digest: digest)
    else
      query = query.order('id desc')
    end

    # Security note, safe due to route constraint
    underscore_digest = digest ? "_" + digest : ""

    cache_path = "#{Rails.root}/#{Stylesheet::Manager::CACHE_PATH}"
    location = "#{cache_path}/#{target}#{underscore_digest}#{extension}"

    stylesheet_time = query.pluck_first(:created_at)

    if !stylesheet_time
      handle_missing_cache(location, target, digest)
    end

    if cache_time && stylesheet_time && stylesheet_time <= cache_time
      return render body: nil, status: 304
    end

    unless File.exist?(location)
      if current = query.pluck_first(source_map ? :source_map : :content)
        FileUtils.mkdir_p(cache_path)
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
    existing = read_file(location)

    if existing && digest
      source_map = read_file(source_map_location)
      StylesheetCache.add(name, digest, existing, source_map)
    end
  end

  private

  def read_file(location)
    begin
      File.read(location)
    rescue Errno::ENOENT
    end
  end

end
