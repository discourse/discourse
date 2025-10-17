# frozen_string_literal: true

module Plugin
  class JsManager
    def self.digested_logical_path_for(script)
      return if !script.start_with?("plugins/")
      Rails
        .application
        .assets
        .load_path
        .assets
        .find do |a|
          a.logical_path.to_s.start_with?("#{script}-") && a.logical_path.extname == ".js"
        end
        &.logical_path
    end

    def compile!
      puts "Running initial compilation of plugins..."
      start = Time.now

      Parallel.each(Discourse.plugins, in_threads: 8) { |plugin| compile_js_bundle(plugin) }

      puts "Finished initial compilation of plugins in #{(Time.now - start).round(2)}s"
    end

    def compile_js_bundle(plugin)
      print "Building #{plugin.directory_name}... "
      start = Time.now

      output_dir = "#{Rails.root}/app/assets/generated/#{plugin.directory_name}/plugins"

      bundles = [
        ["assets/javascripts", plugin.directory_name],
        ["admin/assets/javascripts", "#{plugin.directory_name}_admin"],
      ]

      bundles.each do |js_path, output_name|
        output_path = "#{output_dir}/#{output_name}-"
        # output_map_file = "#{output_dir}/#{output_name}.js.map"

        js_base = "#{plugin.directory}/#{js_path}"

        files = Dir.glob("**/*", base: js_base)

        if files.empty?
          Dir.glob("#{output_path}*").each { |f| File.delete(f) }
          next
        end

        tree = {}
        files.sort.each do |file|
          full_path = File.join(js_base, file)
          tree[file] = File.read(full_path) if File.file?(full_path)
        end

        hex_digest =
          Digest::SHA1.hexdigest(
            [
              *tree.keys,
              *tree.values,
              Theme::BASE_COMPILER_VERSION,
              DiscourseJsProcessor::Transpiler.new.ember_version,
              minify?.to_s,
            ].join,
          )
        base36_digest = hex_digest.to_i(16).to_s(36).first(8)

        output_js_file = "#{output_path}#{base36_digest}.digested.js"
        output_map_file = "#{output_path}#{base36_digest}.digested.js.map"

        if !(File.exist?(output_js_file) && File.exist?(output_map_file))
          compiler = PluginJavascriptCompiler.new(plugin.directory_name, minify: minify?)
          compiler.append_tree(tree)
          compiler.compile!

          FileUtils.mkdir_p(output_dir)
          File.write(
            output_js_file,
            compiler.content + "\n//# sourceMappingURL=#{output_name}.js.map\n",
          )
          File.write(output_map_file, compiler.source_map)
        end

        # Delete any old versions
        Dir
          .glob("#{output_path}*")
          .reject { |f| f == output_js_file || f == output_map_file }
          .each { |f| File.delete(f) }
        next
      end
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
  end
end
