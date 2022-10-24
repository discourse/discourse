# frozen_string_literal: true

# barber patches to re-route raw compilation via ember compat handlebars

class Barber::Precompiler
  def sources
    [File.open("#{Rails.root}/app/assets/javascripts/node_modules/handlebars/dist/handlebars.js"),
     precompiler]
  end

  def precompiler
    if !@precompiler
      loader = File.read("#{Rails.root}/app/assets/javascripts/node_modules/loader.js/dist/loader/loader.js")
      source = File.read("#{Rails.root}/app/assets/javascripts/discourse-common/addon/lib/raw-handlebars.js")

      transpiled = DiscourseJsProcessor.transpile(source, "#{Rails.root}/app/assets/javascripts/", "discourse-common/lib/raw-handlebars")

      @precompiler = StringIO.new <<~JS
        let __RawHandlebars;

        (function(){
          #{loader}
          define("handlebars", ["exports"], function(exports){ exports.default = Handlebars; })
          #{transpiled}
          __RawHandlebars = require("discourse-common/lib/raw-handlebars").default;
        })()

        Barber = {
          precompile: function(string) {
            return __RawHandlebars.precompile(string, false).toString();
          }
        };
      JS

    end

    @precompiler
  end
end

module Discourse
  module Ember
    module Handlebars
      module Helper
        def precompile_handlebars(string, input = nil)
          "requirejs('discourse-common/lib/raw-handlebars').template(#{Barber::Precompiler.compile(string)});"
        end

        def compile_handlebars(string, input = nil)
          "requirejs('discourse-common/lib/raw-handlebars').compile(#{indent(string).inspect});"
        end
      end
    end
  end
end

class Ember::Handlebars::Template
  prepend Discourse::Ember::Handlebars::Helper

  def path_for(module_name, config)
    # We need this for backward-compatibility reasons.
    # Plugins may not have an app subdirectory.
    template_path(module_name, config).inspect.gsub('discourse/templates/', '')
  end

  def global_template_target(namespace, module_name, config)
    "#{namespace}[#{path_for(module_name, config)}]"
  end

  def call(input)
    data = input[:data]
    filename = input[:filename]

    raw = handlebars?(filename)

    if raw
      template = data
    else
      template = mustache_to_handlebars(filename, data)
    end

    template_name = input[:name]

    module_name =
      case config.output_type
      when :amd
        amd_template_target(config.amd_namespace, template_name)
      when :global
        template_path(template_name, config)
      else
        raise "Unsupported `output_type`: #{config.output_type}"
      end

    meta = meta_supported? ? { moduleName: module_name } : false

    if config.precompile
      if raw
        template = precompile_handlebars(template, input)
      else
        template = precompile_ember_handlebars(template, config.ember_template, input, meta)
      end
    else
      if raw
        template = compile_handlebars(data)
      else
        template = compile_ember_handlebars(template, config.ember_template, meta)
      end
    end

    case config.output_type
    when :amd
      "define('#{module_name}', ['exports'], function(__exports__){ __exports__['default'] = #{template} });"
    when :global
      if raw
        return <<~JS
          var __t = #{template};
          requirejs('discourse-common/lib/raw-templates').addRawTemplate(#{path_for(template_name, config)}, __t);
        JS
      end

      target = global_template_target('Ember.TEMPLATES', template_name, config)
      "#{target} = #{template}\n"
    else
      raise "Unsupported `output_type`: #{config.output_type}"
    end
  end

  # FIXME: Previously, ember-handlebars-templates uses the logical path which incorrectly
  # returned paths with the `.raw` extension and our code is depending on the `.raw`
  # to find the right template to use.
  def actual_name(input)
    actual_name = input[:name]
    input[:filename].include?('.raw') ? "#{actual_name}.raw" : actual_name
  end

  private

  def handlebars?(filename)
    filename.to_s =~ /\.raw\.(handlebars|hjs|hbs)/ || filename.to_s.ends_with?(".hbr") || filename.to_s.ends_with?(".hbr.erb")
  end
end
