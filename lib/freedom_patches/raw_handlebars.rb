# barber patches to re-route raw compilation via ember compat handlebars

class Barber::Precompiler
  def sources
    [File.open("#{Rails.root}/vendor/assets/javascripts/handlebars.js"),
     precompiler]
  end

  def precompiler
    if !@precompiler

      source = File.read("#{Rails.root}/app/assets/javascripts/discourse/lib/raw-handlebars.js.es6")
      template = Tilt::ES6ModuleTranspilerTemplate.new {}
      transpiled = template.babel_transpile(source)

      # very hacky but lets us use ES6. I'm ashamed of this code -RW
      transpiled.gsub!(/^export .*$/, '')

      @precompiler = StringIO.new <<END
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
END
    end

    @precompiler
  end
end

module Discourse
  module Ember
    module Handlebars
      module Helper
        def precompile_handlebars(string)
          "Discourse.EmberCompatHandlebars.template(#{Barber::Precompiler.compile(string)});"
        end

        def compile_handlebars(string)
          "require('discourse/lib/raw-handlebars').compile(#{indent(string).inspect});"
        end
      end
    end
  end
end

class Ember::Handlebars::Template
  include Discourse::Ember::Handlebars::Helper

  # FIXME: Previously, ember-handlebars-templates uses the logical path which incorrectly
  # returned paths with the `.raw` extension and our code is depending on the `.raw`
  # to find the right template to use.
  def actual_name(input)
    actual_name = input[:name]
    input[:filename].include?('.raw') ? "#{actual_name}.raw" : actual_name
  end
end
