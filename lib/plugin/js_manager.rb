module Plugin
  class JsManager
    def compile!
      # concurrency = 2

      # MiniRacer::Platform.set_flags!(:single_threaded)
      # js_processors = concurrency.times.map { DiscourseJsProcessor::Transpiler.create_new_context }
      puts "Running initial compilation of plugins..."
      start = Time.now

      # js_processors = concurrency.times.map { DiscourseJsProcessor::Transpiler.create_new_context }
      # processor = nil

      Discourse.plugins.each do |plugin|
        # processor = js_processors[Parallel.worker_number]
        compile_js_bundle(plugin)
      end

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
        output_js_file = "#{output_dir}/#{output_name}.js"
        output_map_file = "#{output_dir}/#{output_name}.js.map"

        js_base = "#{plugin.directory}/#{js_path}"

        files = Dir.glob("**/*", base: js_base)

        if files.empty?
          # puts "No JS files found for plugin '#{plugin.directory_name}', skipping."
          File.delete(output_js_file) if File.exist?(output_js_file)
          File.delete(output_map_file) if File.exist?(output_map_file)
          next
        end

        tree = {}
        files.each do |file|
          full_path = File.join(js_base, file)
          tree[file] = File.read(full_path) if File.file?(full_path)
        end

        compiler = PluginJavascriptCompiler.new(plugin.directory_name, minify: false)
        compiler.append_tree(tree)
        compiler.compile!

        FileUtils.mkdir_p(output_dir)
        File.write(
          output_js_file,
          compiler.content + "\n//# sourceMappingURL=#{output_name}.js.map\n",
        )
        File.write(output_map_file, compiler.source_map)
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
        sleep
      ensure
        listener.stop
      end
    end
  end
end
