# frozen_string_literal: true

class ThemeJavascriptCompiler

  module PrecompilerExtension
    def initialize(theme_id)
      super()
      @theme_id = theme_id
    end

    def discourse_node_manipulator
      <<~JS
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
          [
            "SubExpression",
            "MustacheStatement"
          ].forEach((pass) => {
            let visitor = new Handlebars.Visitor();
            visitor.mutating = true;
            visitor[pass] = manipulateNode;
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
              MustacheStatement: manipulateNode
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
        if ('require' in window) {
          require("discourse/lib/theme-settings-store").registerSettings(#{@theme_id}, #{settings_hash.to_json});
        }
      })();
    JS
  end

  # TODO Error handling for handlebars templates
  def append_ember_template(name, hbs_template)
    if !name.start_with?("javascripts/")
      prefix = "javascripts"
      prefix += "/" if !name.start_with?("/")
      name = prefix + name
    end
    name = name.inspect
    compiled = EmberTemplatePrecompiler.new(@theme_id).compile(hbs_template)
    # the `'Ember' in window` check is needed for no_ember pages
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

  def raw_template_name(name)
    name = name.sub(/\.(raw|hbr)$/, '')
    name.inspect
  end

  def append_raw_template(name, hbs_template)
    compiled = RawTemplatePrecompiler.new(@theme_id).compile(hbs_template)
    @content << <<~JS
      (function() {
        const addRawTemplate = requirejs('discourse-common/lib/raw-templates').addRawTemplate;
        const template = requirejs('discourse-common/lib/raw-handlebars').template(#{compiled});
        addRawTemplate(#{raw_template_name(name)}, template);
      })();
    JS
  rescue Barber::PrecompilerError => e
    raise CompileError.new e.instance_variable_get(:@error) # e.message contains the entire template, which could be very long
  end

  def append_raw_script(script)
    @content << script + "\n"
  end

  def append_module(script, name, include_variables: true)
    name = "discourse/theme-#{@theme_id}/#{name.gsub(/^discourse\//, '')}"
    script = "#{theme_settings}#{script}" if include_variables
    transpiler = DiscourseJsProcessor::Transpiler.new
    @content << <<~JS
      if ('define' in window) {
      #{transpiler.perform(script, "", name).strip}
      }
    JS
  rescue MiniRacer::RuntimeError => ex
    raise CompileError.new ex.message
  end

  def append_js_error(message)
    @content << "console.error('Theme Transpilation Error:', #{message.inspect});"
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
