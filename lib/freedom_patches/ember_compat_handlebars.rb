# barber patches to re-route raw compilation via ember compat handlebars
#

module Barber
  class EmberCompatPrecompiler < Barber::Precompiler

    def self.call(template)
      "Handlebars.template(#{compile(template)})"
    end

    def sources
      [handlebars, precompiler]
    end

    def precompiler
    @precompiler ||= StringIO.new <<END
      var Discourse = {};
      #{File.read(Rails.root + "app/assets/javascripts/discourse/lib/ember_compat_handlebars.js")}
      var Barber = {
        precompile: function(string) {
          return Discourse.EmberCompatHandlebars.precompile(string).toString();
        }
      };
END
    end
  end
end

class Ember::Handlebars::Template
  def precompile_handlebars(string)
    "Discourse.EmberCompatHandlebars.template(#{Barber::EmberCompatPrecompiler.compile(string)});"
  end
  def compile_handlebars(string)
    "Discourse.EmberCompatHandlebars.compile(#{indent(string).inspect});"
  end
end
