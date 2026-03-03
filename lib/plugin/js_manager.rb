# frozen_string_literal: true

module Plugin
  class JsManager
    @@manifest_data = {}

    def self.read_manifest(plugin_name)
      manifest_path = "#{Rails.root}/app/assets/generated/#{plugin_name}/manifest.json"

      if Rails.env.production?
        @@manifest_data[plugin_name] ||= JSON.parse(File.read(manifest_path))
      else
        JSON.parse(File.read(manifest_path))
      end
    end

    def self.digested_logical_path_for(plugin_name, entrypoint_name)
      manifest_entry = read_manifest(plugin_name)[entrypoint_name]
      "js/plugins/#{manifest_entry["fileName"].delete_suffix(".js")}" if manifest_entry
    end

    def self.import_paths_for(plugin_name, entrypoint_name)
      read_manifest(plugin_name)[entrypoint_name]["imports"].map do
        "js/plugins/#{it.delete_suffix(".js")}"
      end
    end

    def compile!
      log "Compiling #{Discourse.plugins.count} plugins..."
      start = Time.now

      if !GlobalSetting.mini_racer_single_threaded && AssetProcessor.booted?
        raise "[Plugin::JSManager] Cannot fork for parallel compilation because AssetProcessor is already booted."
      end

      parallel_count = [Etc.nprocessors, 4].min

      Parallel.each(Discourse.plugins, in_processes: parallel_count) do |plugin|
        compile_js_bundle(plugin)
      end

      log "Finished initial compilation of plugins in #{(Time.now - start).round(2)}s"
    end

    def compile_js_bundle(plugin)
      base_output_dir = "#{Rails.root}/app/assets/generated/#{plugin.directory_name}"
      js_dir = "#{base_output_dir}/js/plugins"
      map_dir = "#{base_output_dir}/map/plugins"

      entrypoints = { "main" => "assets/javascripts", "admin" => "admin/assets/javascripts" }
      entrypoints["test"] = "test/javascripts" if Rails.env.local?

      tree = {}
      entrypoints_config = {}

      entrypoints.each do |name, js_path|
        js_base = "#{plugin.directory}/#{js_path}"

        files = Dir.glob("**/*", base: js_base)

        next if files.empty?

        entrypoints_config[name] = { modules: [] }

        files.sort.each do |file|
          full_path = File.join(js_base, file)
          if File.file?(full_path)
            normalized_file_path = file.sub(/\.js\.es6$/, ".js")
            tree[normalized_file_path] = File.read(full_path)
            if name == "test" && file.match(%r{/(acceptance|integration|unit)/})
              if file.match?(/-test\.g?js$/)
                entrypoints_config[name][:modules] << normalized_file_path
              end
            else
              entrypoints_config[name][:modules] << normalized_file_path
            end
          end
        end
      end

      hex_digest =
        Digest::SHA1.hexdigest(
          [
            *tree.keys,
            *tree.values,
            AssetProcessor::BASE_COMPILER_VERSION,
            AssetProcessor.ember_version,
            minify?.to_s,
          ].join,
        )
      base36_digest = hex_digest.to_i(16).to_s(36).first(8)

      filename_prefix = "#{plugin.directory_name}_"
      filename_suffix = "-#{base36_digest}.digested"

      expected_entrypoints =
        entrypoints_config.keys.map do |name|
          "#{js_dir}/#{filename_prefix}#{name}#{filename_suffix}.js"
        end

      files_exist = expected_entrypoints.all? { |path| File.exist?(path) }

      if !cache? || !files_exist
        compiler =
          Plugin::JsCompiler.new(
            plugin.directory_name,
            minify: minify?,
            tree: tree,
            entrypoints: entrypoints_config,
            filename_prefix:,
            filename_suffix:,
          )
        result = compiler.compile!

        FileUtils.mkdir_p(js_dir)
        FileUtils.mkdir_p(map_dir)

        manifest = {}
        result.each do |file_name, info|
          code = info["code"]
          code += "\n//# sourceMappingURL=../../map/plugins/#{file_name}.map\n" if info["map"]
          File.write("#{js_dir}/#{file_name}", code)

          File.write("#{map_dir}/#{file_name}.map", info["map"]) if info["map"]

          if info["isEntry"]
            manifest[info["name"]] = { fileName: file_name, imports: info["imports"] }
          end
        end

        File.write("#{base_output_dir}/manifest.json", JSON.pretty_generate(manifest))
      end

      # Delete any old versions
      Dir
        .glob("#{base_output_dir}/*/*/*")
        .reject { |path| path.include?(filename_suffix) || path.include?("_extra") }
        .each { |path| FileUtils.rm_rf(path) }
    end

    def watch
      listener =
        Listen.to(
          *Discourse.plugins.map(&:directory),
          { ignore: [%r{/node_modules/}], only: /\.(gjs|js|hbs)\z/ },
        ) do |modified, added, removed|
          changed_files = modified + added + removed
          changed_plugins = Set.new

          log "Changed files:"
          changed_files.each do |file|
            relative_path = Pathname.new(file).relative_path_from(Rails.root)
            log "- #{relative_path}"

            plugin = Discourse.plugins.find { |p| file.start_with?(p.directory) }
            changed_plugins << plugin if plugin
          end

          log "Recompiling..."
          start = Time.now
          changed_plugins.each { |plugin| compile_js_bundle(plugin) }
          log "Finished recompilation in #{(Time.now - start).round(2)}s"

          MessageBus.publish("/file-change", ["refresh"])
        rescue => e
          log "Plugin JS watcher crashed \n#{e}"
        end

      begin
        listener.start
        compile!
        yield
      ensure
        listener.stop
      end
    end

    def minify?
      Rails.env.production?
    end

    def cache?
      true
    end

    def log(message)
      STDERR.puts "[Plugin::JsManager] #{message}"
    end
  end
end
