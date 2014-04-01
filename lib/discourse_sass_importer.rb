# This custom importer is used for site customizations. This is similar to the
# Sprockets::SassImporter implementation provided in sass-rails since that is used
# during asset precompilation.
class DiscourseSassImporter < Sass::Importers::Filesystem
  GLOB = /\*|\[.+\]/

  def initialize(*args)
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

  def find_relative(name, base, options)
    if name =~ GLOB
      glob_imports(name, Pathname.new(base), options)
    else
      engine_from_path(name, File.dirname(base), options)
    end
  end

  def find(name, options)
    if name =~ GLOB
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

    def engine_from_path(name, dir, options)
      full_filename, syntax = Sass::Util.destructure(find_real_file(dir, name, options))
      return unless full_filename && File.readable?(full_filename)

      Sass::Engine.for_file(full_filename, options)
    end
end
