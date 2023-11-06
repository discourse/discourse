# frozen_string_literal: true

module EmberCli
  def self.dist_dir
    "#{Rails.root}/app/assets/javascripts/discourse/dist"
  end

  def self.assets
    @assets ||= Dir.glob("**/*.{js,map,txt}", base: "#{dist_dir}/assets")
  end

  def self.script_chunks
    return @chunk_infos if @chunk_infos

    chunk_infos = JSON.parse(File.read("#{dist_dir}/assets.json"))

    chunk_infos.transform_keys! { |key| key.delete_prefix("assets/").delete_suffix(".js") }

    chunk_infos.transform_values! do |value|
      value["assets"].map { |chunk| chunk.delete_prefix("assets/").delete_suffix(".js") }
    end

    @chunk_infos = chunk_infos if Rails.env.production?
    chunk_infos
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
    @chunk_infos = nil
    @assets = nil
  end
end
