module Ember
  module Handlebars
    class Template < Tilt::Template

      # Wrap in an IIFE in development mode to get the correct filename
      def compile_ember_handlebars(string)
        if ::Rails.env.development?
          "(function() { try { return Ember.Handlebars.compile(#{indent(string).inspect}); } catch(err) { throw err; } })()"
        else
          "Handlebars.compile(#{indent(string).inspect});"
        end
      end
    end
  end
end

