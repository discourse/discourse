# frozen_string_literal: true

SanePatch.patch("ember-handlebars-template", "~> 0.8.0") do
  module FreedomPatches
    module EmberHandlebars
      # Wrap in an IIFE in development mode to get the correct filename
      def compile_ember_handlebars(string, ember_template = 'Handlebars', options = nil)
        return super unless Rails.env.development?
        "(function() { try { return Ember.#{ember_template}.compile(#{indent(string).inspect}); } catch(err) { throw err; } })()"
      end

      # TODO: Remove this after we move to Ember CLI
      def template_path(path, config)
        config.templates_root.each do |k, v|
          path = path.sub(/#{Regexp.quote(k)}\//, v)
        end
        path.split('/').join(config.templates_path_separator)
      end

      Ember::Handlebars::Template.prepend(self)
    end
  end
end
