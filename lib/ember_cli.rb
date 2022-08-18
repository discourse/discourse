# frozen_string_literal: true

module EmberCli
  def self.plugin_assets?
    ENV["EMBER_CLI_PLUGIN_ASSETS"] == "1"
  end

  def self.assets
    @assets ||= begin
      assets = %w(
        discourse.js
        admin.js
        wizard.js
        ember_jquery.js
        pretty-text-bundle.js
        start-discourse.js
        vendor.js
      )
      assets += Dir.glob("app/assets/javascripts/discourse/scripts/*.js").map { |f| File.basename(f) }

      if plugin_assets?
        Discourse.find_plugin_js_assets(include_disabled: true).each do |file|
          next if file.ends_with?("_extra") # these are still handled by sprockets
          assets << "#{file}.js"
        end
      end

      assets
    end
  end

  def self.script_chunks
    return @@chunk_infos if defined? @@chunk_infos

    raw_chunk_infos = JSON.parse(File.read("#{Rails.configuration.root}/app/assets/javascripts/discourse/dist/chunks.json"))

    chunk_infos = raw_chunk_infos["scripts"].map do |info|
      logical_name = info["afterFile"][/\Aassets\/(.*)\.js\z/, 1]
      chunks = info["scriptChunks"].map { |filename| filename[/\Aassets\/(.*)\.js\z/, 1] }
      [logical_name, chunks]
    end.to_h

    @@chunk_infos = chunk_infos if Rails.env.production?
    chunk_infos
  rescue Errno::ENOENT
    {}
  end

  def self.is_ember_cli_asset?(name)
    assets.include?(name) || name.start_with?("chunk.")
  end
end
