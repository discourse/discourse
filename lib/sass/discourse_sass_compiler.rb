require_dependency 'sass/discourse_sass_importer'

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
  end

  # Compiles the given scss and output the css as a string.
  #
  # Options:
  #   safe: (boolean) if true, theme and plugin stylesheets will not be included. Default is false.
  def compile(opts={})
    env = Rails.application.assets

    # In production Rails.application.assets is a Sprockets::Index
    #  instead of Sprockets::Environment, there is no cleaner way
    #  to get the environment from the index.
    if env.is_a?(Sprockets::Index)
      env = env.instance_variable_get('@environment')
    end

    context = env.context_class.new(env, "#{@target}.scss", "app/assets/stylesheets/#{@target}.scss")

    ::Sass::Engine.new(@scss, {
      syntax: :scss,
      cache: false,
      read_cache: false,
      style: Rails.env.production? ? :compressed : :expanded,
      filesystem_importer: opts[:safe] ? DiscourseSafeSassImporter : DiscourseSassImporter,
      sprockets: {
        context: context,
        environment: context.environment
      }
    }).render
  end

end
