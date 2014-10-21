# This custom importer is used for site customizations. This is similar to the
# Sprockets::SassImporter implementation provided in sass-rails since that is used
# during asset precompilation.
class DiscourseSassImporter < Sass::Importers::Filesystem
  GLOB = /\*|\[.+\]/ unless defined? GLOB

  # Depending upon where this is passed we might either be passed a string as the
  # first argument or a sprockets context. If the first argument is a sprockets
  # context we store it and use it to mark dependencies.
  def initialize(*args)
    @context = args.first unless args.first.is_a? String
    @root = Rails.root.join('app', 'assets', 'stylesheets').to_s
    @same_name_warnings = Set.new
  end

  def extensions
    {
      'css' => :scss,
      'css.scss' => :scss,
      'css.sass' => :sass,
      'css.erb' => :scss,
      'scss.erb' => :scss,
      'sass.erb' => :sass,
      'css.scss.erb' => :scss,
      'css.sass.erb' => :sass
    }.merge!(super)
  end

  def special_imports
    {
      "plugins" => DiscoursePluginRegistry.stylesheets,
      "plugins_mobile" => DiscoursePluginRegistry.mobile_stylesheets,
      "plugins_desktop" => DiscoursePluginRegistry.desktop_stylesheets,
      "plugins_variables" => DiscoursePluginRegistry.sass_variables,
      "theme_variables" => [ColorScheme::BASE_COLORS_FILE]
    }
  end

  def find_relative(name, base, options)
    if name =~ GLOB
      glob_imports(name, Pathname.new(base), options)
    else
      engine_from_path(name, File.dirname(base), options)
    end
  end

  def find(name, options)

    if name == "category_backgrounds"
      contents = ""
      Category.where('background_url IS NOT NULL').each do |c|
        if c.background_url.present?
          contents << "body.category-#{c.id} { background-image: url(#{c.background_url}) }\n"
        end
      end
      return Sass::Engine.new(contents, options.merge(
        filename: "#{name}.scss",
        importer: self,
        syntax: :scss
      ))
    end

    if special_imports.has_key? name
      if name == "theme_variables"
        contents = ""
        if color_scheme = ColorScheme.enabled
          ColorScheme.base_colors.each do |name, base_hex|
            override = color_scheme.colors_by_name[name]
            contents << "$#{name}: ##{override ? override.hex : base_hex} !default;\n"
          end
        else
          special_imports[name].each do |css_file|
            contents << File.read(css_file)
          end
        end

        Sass::Engine.new(contents, options.merge(
          filename: "#{name}.scss",
          importer: self,
          syntax: :scss
        ))
      else
        stylesheets = special_imports[name]
        contents = ""
        stylesheets.each do |css_file|
          if css_file =~ /\.scss$/
            contents << "@import '#{css_file}';"
          else
            contents << File.read(css_file)
          end
          depend_on(css_file)
        end
        Sass::Engine.new(contents, options.merge(
          filename: "#{name}.scss",
          importer: self,
          syntax: :scss
        ))
      end
    elsif name =~ GLOB
      nil # globs must be relative
    else
      engine_from_path(name, root, options)
    end
  end

  def each_globbed_file(glob, base_pathname, options)
    Dir["#{base_pathname}/#{glob}"].sort.each do |filename|
      next if filename == options[:filename]
      yield filename # assume all matching files are requirable
    end
  end

  def glob_imports(glob, base_pathname, options)
    contents = ""
    each_globbed_file(glob, base_pathname.dirname, options) do |filename|
      depend_on(filename)
      unless File.directory?(filename)
        contents << "@import #{Pathname.new(filename).relative_path_from(base_pathname.dirname).to_s.inspect};\n"
      end
    end
    return nil if contents.empty?
    Sass::Engine.new(contents, options.merge(
      filename: base_pathname.to_s,
      importer: self,
      syntax: :scss
    ))
  end

  private

    def depend_on(filename)
      if @context
        @context.depend_on(filename)
        @context.depend_on(globbed_file_parent(filename))
      end
    end

    def globbed_file_parent(filename)
      if File.directory?(filename)
        File.expand_path('..', filename)
      else
        File.dirname(filename)
      end
    end

    def engine_from_path(name, dir, options)
      full_filename, syntax = Sass::Util.destructure(find_real_file(dir, name, options))
      return unless full_filename && File.readable?(full_filename)

      depend_on(full_filename)
      Sass::Engine.for_file(full_filename, options)
    end
end
