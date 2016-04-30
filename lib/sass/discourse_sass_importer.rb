# This custom importer is used for site customizations. This is similar to the
# Sprockets::SassImporter implementation provided in sass-rails since that is used
# during asset precompilation.
class DiscourseSassImporter < Sass::Importers::Filesystem
  module Sass
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
        "theme_variables" => [ColorScheme::BASE_COLORS_FILE],
        "category_backgrounds" => Proc.new { |c| "body.category-#{c.full_slug} { background-image: url(#{apply_cdn(c.background_url)}) }\n" }
      }
    end

    def find_relative(name, base, options)
      engine_from_path(name, File.dirname(base), options)
    end

    def apply_cdn(url)
      "#{GlobalSetting.cdn_url}#{url}"
    end

    def find(name, options)

      if special_imports.has_key? name
        case name
        when "theme_variables"
          contents = ""
          if color_scheme = ColorScheme.enabled
            ColorScheme.base_colors.each do |n, base_hex|
              override = color_scheme.colors_by_name[n]
              contents << "$#{n}: ##{override ? override.hex : base_hex} !default;\n"
            end
          else
            special_imports[name].each do |css_file|
              contents << File.read(css_file)
            end
          end
        when "category_backgrounds"
          contents = ""
          Category.where('background_url IS NOT NULL').each do |c|
            contents << special_imports[name].call(c) if c.background_url.present?
          end
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
        end

        ::Sass::Engine.new(contents, options.merge(
          filename: "#{name}.scss",
          importer: self,
          syntax: :scss
        ))
      else
        engine_from_path(name, root, options)
      end
    end

    private

      def depend_on(filename)
        if @context
          @context.depend_on(filename)
          @context.depend_on(globbed_file_parent(filename))
        end
      end

      def engine_from_path(name, dir, options)
        full_filename, _ = ::Sass::Util.destructure(find_real_file(dir, name, options))
        return unless full_filename && File.readable?(full_filename)

        depend_on(full_filename)
        ::Sass::Engine.for_file(full_filename, options)
      end
  end

  include Sass
  include ::Sass::Rails::SassImporter::Globbing

  def self.special_imports
    self.new('').special_imports
  end
end
