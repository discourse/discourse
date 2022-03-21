# frozen_string_literal: true

module FreedomPatches
  module RawHandlebars
    # barber patches to re-route raw compilation via ember compat handlebars
    SanePatch.patch("barber", "~> 0.12.2") do
      module Barber
        def sources
          [File.open("#{Rails.root}/vendor/assets/javascripts/handlebars.js"),
           precompiler]
        end

        def precompiler
          if !@precompiler

            source = File.read("#{Rails.root}/app/assets/javascripts/discourse-common/addon/lib/raw-handlebars.js")
            transpiler = DiscourseJsProcessor::Transpiler.new(skip_module: true)
            transpiled = transpiler.perform(source)

            # very hacky but lets us use ES6. I'm ashamed of this code -RW
            transpiled = transpiled[transpiled.index('var RawHandlebars = ')...transpiled.index('export ')]

            @precompiler = StringIO.new <<~JS
              var __RawHandlebars;
              (function() {
                #{transpiled};
                __RawHandlebars = RawHandlebars;
              })();

              Barber = {
                precompile: function(string) {
                  return __RawHandlebars.precompile(string, false).toString();
                }
              };
            JS
          end

          @precompiler
        end

        ::Barber::Precompiler.prepend(self)
      end
    end

    SanePatch.patch("ember-handlebars-template", "~> 0.8.0") do
      module HandleBarsTemplate
        def precompile_handlebars(string, input = nil)
          "requirejs('discourse-common/lib/raw-handlebars').template(#{::Barber::Precompiler.compile(string)});"
        end

        def compile_handlebars(string, input = nil)
          "requirejs('discourse-common/lib/raw-handlebars').compile(#{indent(string).inspect});"
        end

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

        Ember::Handlebars::Template.prepend(self)
      end
    end
  end
end
