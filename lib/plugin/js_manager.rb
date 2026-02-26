# frozen_string_literal: true

module Plugin
  class JsManager
    def self.digested_logical_path_for(plugin_name, entrypoint_name)
      manifest_path = "#{Rails.root}/app/assets/generated/#{plugin_name}/manifest.json"
      manifest = JSON.parse(File.read(manifest_path))
      entrypoint_filename = manifest[entrypoint_name]["fileName"]

      "js/plugins/#{entrypoint_filename.sub(/\.js$/, "")}"
    end

    def compile!
      puts "[Plugin::JSManager] Compiling plugins..."
      start = Time.now

      Parallel.each(Discourse.plugins, in_threads: 1) { |plugin| compile_js_bundle(plugin) }

      puts "[Plugin::JSManager] Finished initial compilation of plugins in #{(Time.now - start).round(2)}s"
    end

    def compile_js_bundle(plugin)
      print "Building #{plugin.directory_name}... "
      start = Time.now

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
            Theme::BASE_COMPILER_VERSION,
            AssetProcessor.new.ember_version,
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

      puts "done (#{(Time.now - start).round(2)}s)"
    end

    def watch
      listener =
        Listen.to(
          *Discourse.plugins.map(&:directory),
          { ignore: [%r{/node_modules/}], only: /\.(gjs|js|hbs)\z/ },
        ) do |modified, added, removed|
          changed_files = modified + added + removed
          changed_plugins = Set.new

          changed_files.each do |file|
            puts file
            plugin = Discourse.plugins.find { |p| file.start_with?(p.directory) }
            changed_plugins << plugin if plugin
          end

          puts "Changed plugins #{changed_plugins.map(&:directory_name).join(", ")}"
          changed_plugins.each { |plugin| compile_js_bundle(plugin) }
          MessageBus.publish("/file-change", ["refresh"])
        rescue => e
          STDERR.puts "Plugin JS watcher crashed \n#{e}"
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
  end
end
