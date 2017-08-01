module Ember
  module Handlebars
    class Template

      # Wrap in an IIFE in development mode to get the correct filename
      def compile_ember_handlebars(string, ember_template = 'Handlebars', options = nil)
        if ::Rails.env.development?
          "(function() { try { return Ember.#{ember_template}.compile(#{indent(string).inspect}); } catch(err) { throw err; } })()"
        else
          "Ember.#{ember_template}.compile(#{indent(string).inspect}, #{options.to_json});"
        end
      end
    end
  end
end
