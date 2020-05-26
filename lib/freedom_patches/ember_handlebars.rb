# frozen_string_literal: true

class Ember::Handlebars::Template

  # TODO: Remove this after we move to Ember CLI
  def template_path(path, config)
    root = config.templates_root

    config.templates_root.each do |k, v|
      path = path.sub(/#{Regexp.quote(k)}\//, v)
    end

    path.split('/').join(config.templates_path_separator)
  end
end
