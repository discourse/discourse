require_dependency 'sass/discourse_sass_importer'
require 'pathname'

module Sass::Script::Functions
  def _error(message)
    raise Sass::SyntaxError, mesage
  end
end

class DiscourseSassCompiler

  def self.compile(scss, target, opts={})
    self.new(scss, target).compile(opts)
  end

  # Takes a Sass::SyntaxError and generates css that will show the
  # error at the bottom of the page.
  def self.error_as_css(sass_error, label)
    error = sass_error.sass_backtrace_str(label)
    error.gsub!("\n", '\A ')
    error.gsub!("'", '\27 ')

    "footer { white-space: pre; }
    footer:after { content: '#{error}' }"
  end


  def initialize(scss, target)
    @scss = scss
    @target = target

    unless Sass::Script::Functions < Sprockets::SassFunctions
      Sass::Script::Functions.send :include, Sprockets::SassFunctions
    end
  end

  # Compiles the given scss and output the css as a string.
  #
  # Options:
  #   safe: (boolean) if true, theme and plugin stylesheets will not be included. Default is false.
  def compile(opts={})
    app = Rails.application
    env = app.assets || Sprockets::Railtie.build_environment(app)

    pathname = Pathname.new("app/assets/stylesheets/#{@target}.scss")

    context = env.context_class.new(
      environment: env,
      filename: "#{@target}.scss",
      pathname: pathname,
      metadata: {}
    )

    debug_opts = Rails.env.production? ? {} : {
      line_numbers: true,
      # debug_info: true, # great with Firebug + FireSass, but not helpful elsewhere
      style: :expanded
    }

    importer_class = opts[:safe] ? DiscourseSafeSassImporter : DiscourseSassImporter

    css = ::Sass::Engine.new(@scss, {
      syntax: :scss,
      cache: false,
      read_cache: false,
      style: :compressed,
      filesystem_importer: importer_class,
      load_paths: context.environment.paths.map { |path| importer_class.new(path.to_s) },
      sprockets: {
        context: context,
        environment: context.environment
      }
    }.merge(debug_opts)).render

    css_output = css
    if opts[:rtl]
      begin
        require 'r2'
        css_output = R2.r2(css) if defined?(R2)
      rescue; end
    end
    css_output
  end

end
