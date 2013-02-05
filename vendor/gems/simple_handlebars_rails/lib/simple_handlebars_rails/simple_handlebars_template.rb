require 'tilt/template'

module SimpleHandlebarsRails

  # = Sprockets engine for MustacheTemplate templates
  class SimpleHandlebarsTemplate < Tilt::Template
    def self.default_mime_type
      'application/javascript'
    end

    def initialize_engine
    end

    def prepare
    end

    # Generates Javascript code from a HandlebarsJS template.
    # The SC template name is derived from the lowercase logical asset path
    # by replacing non-alphanum characheters by underscores.
    def evaluate(scope, locals, &block)

      template = data.dup
      template.gsub!(/"/, '\\"')
      template.gsub!(/\r?\n/, '\\n')
      template.gsub!(/\t/, '\\t')

      # TODO: make this an option
      templateName = scope.logical_path.downcase.gsub(/[^a-z0-9\/]/, '_')
      templateName.gsub!(/^discourse\/templates\//, '')

      # TODO precompile so we can just have handlebars-runtime in prd

      result = "if (typeof HANDLEBARS_TEMPLATES == 'undefined') HANDLEBARS_TEMPLATES = {};\n"
      result << "HANDLEBARS_TEMPLATES[\"#{templateName}\"] = Handlebars.compile(\"#{template}\");\n"
      result
    end
  end
end
