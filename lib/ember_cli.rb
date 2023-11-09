# frozen_string_literal: true

class EmberCli < ActiveSupport::CurrentAttributes
  # Cache which persists for the duration of a request
  attribute :request_cached_script_chunks

  def self.dist_dir
    "#{Rails.root}/app/assets/javascripts/discourse/dist"
  end

  def self.assets
    @assets ||= Dir.glob("**/*.{js,map,txt}", base: "#{dist_dir}/assets")
  end

  def self.script_chunks
    return @production_chunk_infos if @production_chunk_infos
    return self.request_cached_script_chunks if self.request_cached_script_chunks

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

    @production_chunk_infos = chunk_infos if Rails.env.production?
    self.request_cached_script_chunks = chunk_infos
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
          File.read("#{Rails.root}/app/assets/javascripts/node_modules/ember-source/package.json")
        JSON.parse(ember_source_package_raw)["version"]
      end
  end

  def self.workbox_dir_name
    return @workbox_base_dir if defined?(@workbox_base_dir)

    @workbox_base_dir =
      if (full_path = Dir.glob("app/assets/javascripts/discourse/dist/assets/workbox-*")[0])
        File.basename(full_path)
      end
  end

  def self.has_tests?
    File.exist?("#{dist_dir}/tests/index.html")
  end

  def self.clear_cache!
    @production_chunk_infos = nil
    @assets = nil
    self.request_cached_script_chunks = nil
  end
end
