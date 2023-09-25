# frozen_string_literal: true

module EmberCli
  def self.dist_dir
    "#{Rails.root}/app/assets/javascripts/discourse/dist"
  end

  def self.assets
    @assets ||=
      begin
        assets = %w[
          discourse.js
          admin.js
          wizard.js
          ember_jquery.js
          markdown-it-bundle.js
          start-discourse.js
          vendor.js
        ]
        assets +=
          Dir.glob("app/assets/javascripts/discourse/scripts/*.js").map { |f| File.basename(f) }

        if workbox_dir_name
          assets +=
            Dir
              .glob("app/assets/javascripts/discourse/dist/assets/#{workbox_dir_name}/*")
              .map { |f| "#{workbox_dir_name}/#{File.basename(f)}" }
        end

        Discourse
          .find_plugin_js_assets(include_disabled: true)
          .each do |file|
            next if file.ends_with?("_extra") # these are still handled by sprockets
            assets << "#{file}.js"
          end

        assets
      end
  end

  def self.script_chunks
    return @@chunk_infos if defined?(@@chunk_infos)

    chunk_infos = {}

    begin
      test_html = File.read("#{dist_dir}/tests/index.html")
      chunk_infos.merge! parse_chunks_from_html(test_html)
    rescue Errno::ENOENT
      # production build
    end

    index_html = File.read("#{dist_dir}/index.html")
    chunk_infos.merge! parse_chunks_from_html(index_html)

    @@chunk_infos = chunk_infos if Rails.env.production?
    chunk_infos
  rescue Errno::ENOENT
    {}
  end

  def self.parse_source_map_path(file)
    File.read("#{dist_dir}/assets/#{file}")[%r{//# sourceMappingURL=(.*)$}, 1]
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

  def self.parse_chunks_from_html(html)
    doc = Nokogiri::HTML5.parse(html)

    chunk_infos = {}

    doc
      .css("discourse-chunked-script")
      .each do |discourse_script|
        entrypoint = discourse_script.attr("entrypoint")
        chunk_infos[entrypoint] = discourse_script
          .css("script[src]")
          .map do |script|
            script.attr("src").delete_prefix("#{Discourse.base_path}/assets/").delete_suffix(".js")
          end
      end

    chunk_infos
  end

  def self.has_tests?
    File.exist?("#{dist_dir}/tests/index.html")
  end
end
