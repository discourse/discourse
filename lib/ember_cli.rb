# frozen_string_literal: true

class EmberCli < ActiveSupport::CurrentAttributes
  # Cache which persists for the duration of a request
  attribute :request_cache

  def self.dist_dir
    "#{Rails.root}/app/assets/javascripts/discourse/dist"
  end

  def self.assets
    cache[:assets] ||= Dir.glob("**/*.{js,map,txt,css}", base: "#{dist_dir}/assets")
  end

  def self.script_chunks
    return cache[:script_chunks] if cache[:script_chunks]

    entrypoints = {}

    vite_manifest = JSON.parse(File.read("#{dist_dir}/.vite/manifest.json"))

    vite_manifest.each do |key, value|
      next unless value["isEntry"]
      entrypoints[key.delete_suffix(".js")] = [
        value["file"].delete_prefix("assets/").delete_suffix(".js"),
      ]
    end
    p entrypoints

    cache[:script_chunks] = entrypoints
  rescue Errno::ENOENT
    {}
  end

  def self.route_bundles
    vite_manifest = JSON.parse(File.read("#{dist_dir}/.vite/manifest.json"))

    route_bundles = {}

    vite_manifest.each do |key, value|
      next unless route = key[/\Aembroider_virtual:.*:route=(.*)\z/, 1]
      route_bundles[route] = deep_preloads_for(key)
    end

    route_bundles
  rescue Errno::ENOENT
    {}
  end

  def self.deep_preloads_for(asset)
    vite_manifest = JSON.parse(File.read("#{dist_dir}/.vite/manifest.json"))

    preloads = []
    seen = Set.new
    seen.add(asset)

    asset = vite_manifest[asset]
    preloads.push asset["file"].delete_prefix("assets/").delete_suffix(".js")

    asset["imports"]&.each do |import|
      next if seen.include?(import)
      seen.add(import)
      preloads.push(*deep_preloads_for(import))
    end

    preloads
  end

  def self.is_ember_cli_asset?(name)
    assets.include?(name) || script_chunks.values.flatten.include?(name.delete_suffix(".js"))
  end

  def self.ember_version
    @version ||=
      begin
        ember_source_package_raw =
          File.read(
            "#{Rails.root}/app/assets/javascripts/discourse/node_modules/ember-source/package.json",
          )
        JSON.parse(ember_source_package_raw)["version"]
      end
  end

  def self.has_tests?
    File.exist?("#{dist_dir}/tests/index.html")
  end

  def self.cache
    if Rails.env.development?
      self.request_cache ||= {}
    else
      @production_cache ||= {}
    end
  end

  def self.clear_cache!
    self.request_cache = nil
    @production_cache = nil
  end
end
