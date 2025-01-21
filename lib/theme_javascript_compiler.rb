# frozen_string_literal: true

class ThemeJavascriptCompiler
  COLOCATED_CONNECTOR_REGEX =
    %r{\A(?<prefix>.*/?)connectors/(?<outlet>[^/]+)/(?<name>[^/\.]+)\.(?<extension>.+)\z}

  class CompileError < StandardError
  end

  @@terser_disabled = false
  def self.disable_terser!
    raise "Tests only" if !Rails.env.test?
    @@terser_disabled = true
  end

  def self.enable_terser!
    raise "Tests only" if !Rails.env.test?
    @@terser_disabled = false
  end

  def initialize(theme_id, theme_name, minify: true)
    @theme_id = theme_id
    @output_tree = []
    @theme_name = theme_name
    @minify = minify
  end

  def compile!
    if !@compiled
      @compiled = true
      @output_tree.freeze

      output =
        if !has_content?
          { "code" => "" }
        elsif @@terser_disabled || !@minify
          { "code" => raw_content }
        else
          DiscourseJsProcessor::Transpiler.new.terser(@output_tree.to_h, terser_config)
        end

      @content = output["code"]
      @source_map = output["map"]
    end
    [@content, @source_map]
  rescue DiscourseJsProcessor::TranspileError => e
    message = "[THEME #{@theme_id} '#{@theme_name}'] Compile error: #{e.message}"
    @content = "console.error(#{message.to_json});\n"
    [@content, @source_map]
  end

  def terser_config
    # Based on https://github.com/ember-cli/ember-cli-terser/blob/28df3d90a5/index.js#L12-L26
    {
      sourceMap: {
        includeSources: true,
        root: "theme-#{@theme_id}/",
      },
      compress: {
        negate_iife: false,
        sequences: 30,
        drop_debugger: false,
      },
      output: {
        semicolons: false,
      },
    }
  end

  def content
    compile!
    @content
  end

  def source_map
    compile!
    @source_map
  end

  def raw_content
    @output_tree.map { |filename, source| source }.join("")
  end

  def has_content?
    @output_tree.present?
  end

  def prepend_settings(settings_hash)
    @output_tree.prepend ["settings.js", <<~JS]
      (function() {
        if ('require' in window) {
          require("discourse/lib/theme-settings-store").registerSettings(#{@theme_id}, #{settings_hash.to_json});
        }
      })();
    JS
  end

  def append_tree(tree, include_variables: true)
    # Replace legacy extensions
    tree.transform_keys! do |filename|
      if filename.ends_with? ".js.es6"
        filename.sub(/\.js\.es6\z/, ".js")
      elsif filename.include? "/templates/"
        filename = filename.sub(/\.raw\.hbs\z/, ".hbr") if filename.ends_with? ".raw.hbs"

        if filename.ends_with? ".hbr"
          filename.sub(%r{/templates/}, "/raw-templates/")
        else
          filename
        end
      else
        filename
      end
    end

    # Some themes are colocating connector JS under `/connectors`. Move template to /templates to avoid module name clash
    tree.transform_keys! do |filename|
      match = COLOCATED_CONNECTOR_REGEX.match(filename)
      next filename if !match

      is_template = match[:extension] == "hbs"
      is_in_templates_directory = match[:prefix].split("/").last == "templates"

      if is_template && !is_in_templates_directory
        "#{match[:prefix]}templates/connectors/#{match[:outlet]}/#{match[:name]}.#{match[:extension]}"
      elsif !is_template && is_in_templates_directory
        "#{match[:prefix].chomp("templates/")}connectors/#{match[:outlet]}/#{match[:name]}.#{match[:extension]}"
      else
        filename
      end
    end

    # Handle colocated components
    tree.dup.each_pair do |filename, content|
      is_component_template =
        filename.end_with?(".hbs") &&
          filename.start_with?("discourse/components/", "admin/components/")
      next if !is_component_template
      template_contents = content

      hbs_invocation_options = { moduleName: filename, parseOptions: { srcName: filename } }
      hbs_invocation = "hbs(#{template_contents.to_json}, #{hbs_invocation_options.to_json})"

      prefix = <<~JS
        import { hbs } from 'ember-cli-htmlbars';
        const __COLOCATED_TEMPLATE__ = #{hbs_invocation};
      JS

      js_filename = filename.sub(/\.hbs\z/, ".js")
      js_contents = tree[js_filename] # May be nil for template-only component
      if js_contents && !js_contents.include?("export default")
        message =
          "#{filename} does not contain a `default export`. Did you forget to export the component class?"
        js_contents += "throw new Error(#{message.to_json});"
      end

      if js_contents.nil?
        # No backing class, use template-only
        js_contents = <<~JS
          import templateOnly from '@ember/component/template-only';
          export default templateOnly();
        JS
      end

      js_contents = prefix + js_contents

      tree[js_filename] = js_contents
      tree.delete(filename)
    end

    # Transpile and write to output
    tree.each_pair do |filename, content|
      module_name, extension = filename.split(".", 2)

      if extension == "js" || extension == "gjs"
        append_module(content, module_name, extension, include_variables:)
      elsif extension == "hbs"
        append_ember_template(module_name, content)
      elsif extension == "hbr"
        append_raw_template(module_name.sub("discourse/raw-templates/", ""), content)
      else
        append_js_error(filename, "unknown file extension '#{extension}' (#{filename})")
      end
    rescue CompileError => e
      append_js_error filename, "#{e.message} (#{filename})"
    end
  end

  def append_ember_template(name, hbs_template)
    module_name = name
    module_name = "/#{module_name}" if !module_name.start_with?("/")
    module_name = "discourse/theme-#{@theme_id}#{module_name}"

    # Mimics the ember-cli implementation
    # https://github.com/ember-cli/ember-cli-htmlbars/blob/d5aa14b3/lib/template-compiler-plugin.js#L18-L26
    script = <<~JS
      import { hbs } from 'ember-cli-htmlbars';
      export default hbs(#{hbs_template.to_json}, { moduleName: #{module_name.to_json} });
    JS

    template_module = DiscourseJsProcessor.transpile(script, "", module_name, theme_id: @theme_id)
    @output_tree << ["#{name}.js", <<~JS]
      if ('define' in window) {
      #{template_module}
      }
    JS
  rescue MiniRacer::RuntimeError, DiscourseJsProcessor::TranspileError => ex
    raise CompileError.new ex.message
  end

  def raw_template_name(name)
    name.sub(/\.(raw|hbr)\z/, "")
  end

  def append_raw_template(name, hbs_template)
    compiled =
      DiscourseJsProcessor::Transpiler.new.compile_raw_template(hbs_template, theme_id: @theme_id)
    source_for_comment = hbs_template.gsub("*/", '*\/').indent(4, " ")
    modern_replacement_marker = hbs_template.include?("{{!-- has-modern-replacement --}}")

    source = <<~JS
      /*
      #{source_for_comment}
      */

      import { template as compiler } from "discourse/lib/raw-handlebars";
      import { addRawTemplate } from "discourse/lib/raw-templates";

      let template = compiler(#{compiled});

      addRawTemplate(#{raw_template_name(name).to_json}, template, {
        themeId: #{@theme_id},
        themeName: #{@theme_name.to_json},
        hasModernReplacement: #{modern_replacement_marker}
      });

      export default template;
    JS

    append_module source, "raw-templates/#{raw_template_name(name)}", "js", include_variables: false
  rescue MiniRacer::RuntimeError, DiscourseJsProcessor::TranspileError => ex
    raise CompileError.new ex.message
  end

  def append_raw_script(filename, script)
    @output_tree << [filename, script + "\n"]
  end

  def append_module(script, name, extension, include_variables: true)
    original_filename = name
    name = "discourse/theme-#{@theme_id}/#{name}"

    script = "#{theme_settings}#{script}" if include_variables
    transpiler = DiscourseJsProcessor::Transpiler.new

    @output_tree << ["#{original_filename}.#{extension}", <<~JS]
      if ('define' in window) {
      #{transpiler.perform(script, "", name, theme_id: @theme_id, extension: extension).strip}
      }
    JS
  rescue MiniRacer::RuntimeError, DiscourseJsProcessor::TranspileError => ex
    raise CompileError.new ex.message
  end

  def append_js_error(filename, message)
    message = "[THEME #{@theme_id} '#{@theme_name}'] Compile error: #{message}"
    append_raw_script filename, "console.error(#{message.to_json});"
  end

  private

  def theme_settings
    <<~JS
      const settings = require("discourse/lib/theme-settings-store")
        .getObjectForTheme(#{@theme_id});
      const themePrefix = (key) => `theme_translations.#{@theme_id}.${key}`;
    JS
  end
end
