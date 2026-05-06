# frozen_string_literal: true

class EmberCli < ActiveSupport::CurrentAttributes
  # Cache which persists for the duration of a request
  attribute :request_cache

  def self.dist_dir
    "#{Rails.root}/frontend/discourse/dist"
  end

  def self.assets
    cache[:assets] ||= Dir.glob("**/*.{js,map,txt,css}", base: "#{dist_dir}/assets")
  end

  def self.script_chunks
    return cache[:script_chunks] if cache[:script_chunks]

    entrypoints = {}

    manifest = JSON.parse(File.read("#{dist_dir}/manifest/manifest.json"))

    manifest.each do |key, value|
      next unless value["isEntry"]
      entrypoints[key.delete_suffix(".js")] = [
        value["file"].delete_prefix("assets/").delete_suffix(".js"),
      ]
    end

    entrypoints["@embroider/virtual/test-support"] = ["test-support"]

    cache[:script_chunks] = entrypoints
  rescue Errno::ENOENT
    {}
  end

  def self.route_bundles
    manifest = JSON.parse(File.read("#{dist_dir}/manifest/manifest.json"))

    route_bundles = {}

    manifest.each do |key, value|
      next unless route = key[/\Aembroider_virtual:.*:route=(.*)\z/, 1]
      route_bundles[route] = deep_preloads_for(key)
    end

    route_bundles
  rescue Errno::ENOENT
    {}
  end

  def self.deep_preloads_for(asset)
    manifest = JSON.parse(File.read("#{dist_dir}/manifest.json"))

    preloads = []
    seen = Set.new
    seen.add(asset)

    asset = manifest[asset]
    preloads.push asset["file"].delete_prefix("assets/").delete_suffix(".js")

    asset["imports"]&.each do |import|
      next if seen.include?(import)
      seen.add(import)
      preloads.push(*deep_preloads_for(import))
    end

    preloads
  end

  # Diagnostic: pre-warm every dynamic-import chunk for the test bundle so the
  # first call to `import("photoswipe")`/`import("pikaday")`/lazy route loads
  # don't fight for CPU during the test run. Used only by qunit.html.erb.
  # Safe no-op when manifest is missing (e.g. ember-cli builds).
  def self.test_dynamic_preloads
    return cache[:test_dynamic_preloads] if cache.key?(:test_dynamic_preloads)
    return cache[:test_dynamic_preloads] = [] if ENV["DISABLE_TEST_PRELOAD"] == "1"
    manifest = JSON.parse(File.read("#{dist_dir}/manifest/manifest.json"))

    by_file = manifest.each_with_object({}) { |(_, v), h| h[v["file"]] = v }
    files = []
    seen = Set.new
    walk = ->(entry) do
      return if !entry || seen.include?(entry["file"])
      seen.add(entry["file"])
      files << entry["file"].delete_prefix("assets/").delete_suffix(".js")
      entry["imports"]&.each { |i| walk.call(by_file[i]) }
    end
    manifest.each_value { |entry| walk.call(entry) if entry["isDynamicEntry"] }
    cache[:test_dynamic_preloads] = files
  rescue Errno::ENOENT
    cache[:test_dynamic_preloads] = []
  end

  def self.is_ember_cli_asset?(name)
    name === "@embroider/virtual/test-support" || assets.include?(name) ||
      script_chunks.values.flatten.include?(name.delete_suffix(".js"))
  end

  def self.has_tests?
    script_chunks["tests/test-entrypoint"].present?
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

  def self.watch!
    FileUtils.mkdir_p("#{dist_dir}/manifest")
    Listen
      .to("#{dist_dir}/manifest") do |modified, added, removed|
        # if [*modified, *added, *removed].any? { |path| path.end_with?("manifest.json") }
        puts "refreshing"
        MessageBus.publish("/file-change", ["refresh"])
        # end
      end
      .start
  end
end
