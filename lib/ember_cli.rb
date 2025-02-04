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

    chunk_infos = JSON.parse(File.read("#{dist_dir}/assets.json"))

    chunk_infos.transform_keys! { |key| key.delete_prefix("assets/").delete_suffix(".js") }

    chunk_infos.transform_values! do |value|
      value["assets"].map { |chunk| chunk.delete_prefix("assets/").delete_suffix(".js") }
    end

    # Special case - vendor.js is fingerprinted by Embroider in production, but not run through Webpack
    if !assets.include?("vendor.js") &&
         fingerprinted = assets.find { |a| a.match?(/^vendor\..*\.js$/) }
      chunk_infos["vendor"] = [fingerprinted.delete_suffix(".js")]
    end

    cache[:script_chunks] = chunk_infos
  rescue Errno::ENOENT
    {}
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
