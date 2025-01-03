# frozen_string_literal: true

class StylesheetsController < ApplicationController
  skip_before_action :redirect_to_login_if_required,
                     :redirect_to_profile_if_required,
                     :check_xhr,
                     :verify_authenticity_token,
                     only: %i[show show_source_map color_scheme]

  before_action :apply_cdn_headers, only: %i[show show_source_map color_scheme]

  def show_source_map
    show_resource(source_map: true)
  end

  def show
    is_asset_path

    show_resource
  end

  def color_scheme
    params.require("id")
    params.permit("theme_id")

    manager = Stylesheet::Manager.new(theme_id: params[:theme_id])
    stylesheet = manager.color_scheme_stylesheet_details(params[:id], "all")
    render json: stylesheet
  end

  protected

  def show_resource(source_map: false)
    extension = source_map ? ".css.map" : ".css"

    no_cookies

    target, digest = params[:name].split(/_([a-f0-9]{40})/)

    cache_time = request.env["HTTP_IF_MODIFIED_SINCE"]

    if cache_time.present?
      begin
        cache_time = Time.rfc2822(cache_time)
      rescue ArgumentError
      end
    end

    query = StylesheetCache.where(target: target)
    if digest
      query = query.where(digest: digest)
    else
      query = query.order("id desc")
    end

    # Security note, safe due to route constraint
    underscore_digest = digest ? "_" + digest : ""

    cache_path = Stylesheet::Manager.cache_fullpath
    location = "#{cache_path}/#{target}#{underscore_digest}#{extension}"

    stylesheet_time = query.pick(:created_at)

    handle_missing_cache(location, target, digest) if !stylesheet_time

    if cache_time.present? && stylesheet_time && stylesheet_time <= cache_time
      return render body: nil, status: 304
    end

    unless File.exist?(location)
      if current = query.pick(source_map ? :source_map : :content)
        FileUtils.mkdir_p(cache_path)
        Discourse::Utils.atomic_write_file(location, current)
      else
        raise Discourse::NotFound
      end
    end

    if Rails.env == "development"
      response.headers["Last-Modified"] = Time.zone.now.httpdate
      immutable_for(1.second)
    else
      response.headers["Last-Modified"] = stylesheet_time.httpdate if stylesheet_time
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
