# barber patches to re-route raw compilation via ember compat handlebars

class Barber::Precompiler
  def sources
    [File.open("#{Rails.root}/vendor/assets/javascripts/handlebars.js"), precompiler]
  end

  def precompiler
  @precompiler ||= StringIO.new <<END
    var Discourse = {};
    #{File.read(Rails.root + "app/assets/javascripts/discourse/lib/ember_compat_handlebars.js")}
    var Barber = {
      precompile: function(string) {
        return Discourse.EmberCompatHandlebars.precompile(string,false).toString();
      }
    };
END
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
          "Discourse.EmberCompatHandlebars.compile(#{indent(string).inspect});"
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
