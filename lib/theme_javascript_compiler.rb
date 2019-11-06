# frozen_string_literal: true

class ThemeJavascriptCompiler

  module PrecompilerExtension
    def initialize(theme_id)
      super()
      @theme_id = theme_id
    end

    def discourse_node_manipulator
      <<~JS

      // Helper to replace old themeSetting syntax
      function generateHelper(settingParts) {
        const settingName = settingParts.join('.');
        return {
            "path": {
              "type": "PathExpression",
              "original": "theme-setting",
              "this": false,
              "data": false,
              "parts": [
                "theme-setting"
              ],
              "depth":0
            },
            "params": [
              {
                type: "NumberLiteral",
                value: #{@theme_id},
                original: #{@theme_id}
              },
              {
                "type": "StringLiteral",
                "value": settingName,
                "original": settingName
              }
            ],
            "hash": {
              "type": "Hash",
              "pairs": [
                {
                  "type": "HashPair",
                  "key": "deprecated",
                  "value": {
                    "type": "BooleanLiteral",
                    "value": true,
                    "original": true
                  }
                }
              ]
            }
          }
      }

      function manipulatePath(path) {
        // Override old themeSetting syntax when it's a param inside another node
        if(path.parts && path.parts[0] == "themeSettings"){
          const settingParts = path.parts.slice(1);
          path.type = "SubExpression";
          Object.assign(path, generateHelper(settingParts))
        }
      }

      function manipulateNode(node) {
        // Magically add theme id as the first param for each of these helpers)
        if (node.path.parts && ["theme-i18n", "theme-prefix", "theme-setting"].includes(node.path.parts[0])) {
          if(node.params.length === 1){
            node.params.unshift({
              type: "NumberLiteral",
              value: #{@theme_id},
              original: #{@theme_id}
            })
          }
        }

        // Override old themeSetting syntax when it's in its own node
        if (node.path.parts && node.path.parts[0] == "themeSettings") {
          Object.assign(node, generateHelper(node.path.parts.slice(1)))
        }
      }
      JS
    end

    def source
      [super, discourse_node_manipulator, discourse_extension].join("\n")
    end
  end

  class RawTemplatePrecompiler < Barber::Precompiler
    include PrecompilerExtension

    def discourse_extension
      <<~JS
        let _superCompile = Handlebars.Compiler.prototype.compile;
        Handlebars.Compiler.prototype.compile = function(program, options) {

          // `replaceGet()` in raw-handlebars.js.es6 adds a `get` in front of things
          // so undo this specific case for the old themeSettings.blah syntax
          let visitor = new Handlebars.Visitor();
          visitor.mutating = true;
          visitor.MustacheStatement = (node) => {
            if(node.path.original == 'get'
              && node.params
              && node.params[0]
              && node.params[0].parts
              && node.params[0].parts[0] == 'themeSettings'){
                node.path.parts = node.params[0].parts
                node.params = []
            }
          };
          visitor.accept(program);

          [
            ["SubExpression", manipulateNode],
            ["MustacheStatement", manipulateNode],
            ["PathExpression", manipulatePath]
          ].forEach((pass) => {
            let visitor = new Handlebars.Visitor();
            visitor.mutating = true;
            visitor[pass[0]] = pass[1];
            visitor.accept(program);
          })

          return _superCompile.apply(this, arguments);
        };
      JS
    end
  end

  class EmberTemplatePrecompiler < Barber::Ember::Precompiler
    include PrecompilerExtension

    def discourse_extension
      <<~JS
        Ember.HTMLBars.registerPlugin('ast', function() {
          return {
            name: 'theme-template-manipulator',
            visitor: {
              SubExpression: manipulateNode,
              MustacheStatement: manipulateNode,
              PathExpression: manipulatePath
            }
          }
        });
      JS
    end
  end

  class CompileError < StandardError
  end

  attr_accessor :content

  def initialize(theme_id, theme_name)
    @theme_id = theme_id
    @content = +""
    @theme_name = theme_name
  end

  def prepend_settings(settings_hash)
    @content.prepend <<~JS
      (function() {
        if ('Discourse' in window && Discourse.__container__) {
          Discourse.__container__
            .lookup("service:theme-settings")
            .registerSettings(#{@theme_id}, #{settings_hash.to_json});
        }
      })();
    JS
  end

  # TODO Error handling for handlebars templates
  def append_ember_template(name, hbs_template)
    name = name.inspect
    compiled = EmberTemplatePrecompiler.new(@theme_id).compile(hbs_template)
    content << <<~JS
      (function() {
        if ('Ember' in window) {
          Ember.TEMPLATES[#{name}] = Ember.HTMLBars.template(#{compiled});
        }
      })();
    JS
  rescue Barber::PrecompilerError => e
    raise CompileError.new e.instance_variable_get(:@error) # e.message contains the entire template, which could be very long
  end

  def append_raw_template(name, hbs_template)
    name = name.sub(/\.raw$/, '').inspect
    compiled = RawTemplatePrecompiler.new(@theme_id).compile(hbs_template)
    @content << <<~JS
      (function() {
        if ('Discourse' in window) {
          Discourse.RAW_TEMPLATES[#{name}] = requirejs('discourse-common/lib/raw-handlebars').template(#{compiled});
        }
      })();
    JS
  rescue Barber::PrecompilerError => e
    raise CompileError.new e.instance_variable_get(:@error) # e.message contains the entire template, which could be very long
  end

  def append_plugin_script(script, api_version)
    @content << transpile(script, api_version)
  end

  def append_raw_script(script)
    @content << script + "\n"
  end

  def append_module(script, name, include_variables: true)
    script = "#{theme_variables}#{script}" if include_variables
    template = Tilt::ES6ModuleTranspilerTemplate.new {}
    @content << template.module_transpile(script, "", name)
  rescue MiniRacer::RuntimeError => ex
    raise CompileError.new ex.message
  end

  def append_js_error(message)
    @content << "console.error('Theme Transpilation Error:', #{message.inspect});"
  end

  private

  def theme_variables
    <<~JS
      const __theme_name__ = "#{@theme_name.gsub('"', "\\\"")}";
      const settings = Discourse.__container__
        .lookup("service:theme-settings")
        .getObjectForTheme(#{@theme_id});
      const themePrefix = (key) => `theme_translations.#{@theme_id}.${key}`;
    JS
  end

  def transpile(es6_source, version)
    template = Tilt::ES6ModuleTranspilerTemplate.new {}
    wrapped = <<~PLUGIN_API_JS
      (function() {
        if ('Discourse' in window && typeof Discourse._registerPluginCode === 'function') {
          #{theme_variables}
          Discourse._registerPluginCode('#{version}', api => {
            try {
            #{es6_source}
            } catch(err) {
              const rescue = require("discourse/lib/utilities").rescueThemeError;
              rescue(__theme_name__, err, api);
            }
          });
        }
      })();
    PLUGIN_API_JS

    template.babel_transpile(wrapped)
  rescue MiniRacer::RuntimeError => ex
    raise CompileError.new ex.message
  end
end
