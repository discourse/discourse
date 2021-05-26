# frozen_string_literal: true

module Onebox
  module TemplateSupport
    def load_paths
      Onebox.options.load_paths.select(&method(:template?))
    end

    def template?(path)
      File.exist?(File.join(path, "#{template_name}.#{template_extension}"))
    end
  end
end
