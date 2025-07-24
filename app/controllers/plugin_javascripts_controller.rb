# frozen_string_literal: true

class PluginJavascriptsController < ApplicationController
  @@cache = nil

  skip_before_action :check_xhr,
                     :preload_json,
                     :redirect_to_login_if_required,
                     :verify_authenticity_token

  def show
    plugin = params[:plugin_name]

    start = Time.now
    js_base = "#{Rails.root}/plugins/#{plugin}/assets/javascripts"
    files = Dir.glob("**/*", base: js_base)
    tree = {}
    files.each do |file|
      full_path = File.join(js_base, file)
      tree[file] = File.read(full_path) if File.file?(full_path)
    end
    puts "Loaded #{files.size} files from plugin '#{plugin}' in #{Time.now - start}s"

    compiler = ThemeJavascriptCompiler.new(0, "#{plugin} plugin", {}, minify: false, cache: @@cache)
    compiler.append_tree(tree)
    compiler.compile!
    @@cache = compiler.cache
    puts "Compiled plugin '#{plugin}' in #{Time.now - start}s with cache size #{@@cache.size}"

    content = compiler.content
    if compiler.source_map
      content +=
        "\n//# sourceMappingURL=data:application/json;base64,#{Base64.strict_encode64(compiler.source_map)}\n"
    end

    render plain: content, content_type: "application/javascript"
  end
end
