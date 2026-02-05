# frozen_string_literal: true

module Plugin
  class JsManager
    def self.digested_logical_path_for(script)
      return if !script.start_with?("plugins/")
      _, plugin_name, filename = script.split("/")

      # Todo: optimize this lookup
      Rails
        .application
        .assets
        .load_path
        .assets
        .find do |a|
          a.logical_path.to_s.start_with?("plugins/#{plugin_name}-") &&
            a.logical_path.basename.to_s == "#{filename}.js"
        end
        &.logical_path
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

      output_dir = "#{Rails.root}/app/assets/generated/#{plugin.directory_name}/plugins"

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
            tree[file] = File.read(full_path)
            if name == "test" && file.match(%r{/(acceptance|integration|unit)/})
              entrypoints_config[name][:modules] << file if file.match?(/-test\.g?js$/)
            else
              entrypoints_config[name][:modules] << file
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
            # AssetProcessor.new.ember_version, # TODO: This is annoyingly slow
            minify?.to_s,
          ].join,
        )
      base36_digest = hex_digest.to_i(16).to_s(36).first(8)

      output_path = "#{output_dir}/#{plugin.directory_name}-#{base36_digest}.digested"

      if !(cache? && Dir.exist?(output_path))
        compiler =
          Plugin::JsCompiler.new(
            plugin.directory_name,
            minify: minify?,
            tree: tree,
            entrypoints: entrypoints_config,
          )
        result = compiler.compile!

        FileUtils.mkdir_p(output_path)
        result.each do |file, info|
          code = info["code"]
          code += "\n//# sourceMappingURL=#{file}.map\n" if info["map"]
          File.write("#{output_path}/#{file}", code)

          File.write("#{output_path}/#{file}.map", info["map"]) if info["map"]
        end
      end

      # Delete any old versions
      Dir
        .glob("#{output_dir}/#{plugin.directory_name}*")
        .reject { |path| path == output_path }
        .each { |path| FileUtils.rm_rf(path) }

      puts "done (#{(Time.now - start).round(2)}s)"
    end

    def watch
      listener =
        Listen.to(
          *Discourse.plugins.map(&:directory),
          { ignore: [%r{/node_modules/}], only: /\.g?js\z/ },
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
