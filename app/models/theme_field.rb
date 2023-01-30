# frozen_string_literal: true

class ThemeField < ActiveRecord::Base
  belongs_to :upload
  has_one :javascript_cache, dependent: :destroy
  has_one :upload_reference, as: :target, dependent: :destroy

  after_save do
    if self.type_id == ThemeField.types[:theme_upload_var] && saved_change_to_upload_id?
      UploadReference.ensure_exist!(upload_ids: [self.upload_id], target: self)
    end
  end

  scope :find_by_theme_ids,
        ->(theme_ids) {
          return none unless theme_ids.present?

          where(theme_id: theme_ids).joins(
            "JOIN (
          SELECT #{theme_ids.map.with_index { |id, idx| "#{id.to_i} AS theme_id, #{idx} AS theme_sort_column" }.join(" UNION ALL SELECT ")}
        ) as X ON X.theme_id = theme_fields.theme_id",
          ).order("theme_sort_column")
        }

  scope :filter_locale_fields,
        ->(locale_codes) {
          return none unless locale_codes.present?

          where(target_id: Theme.targets[:translations], name: locale_codes).joins(
            DB.sql_fragment(
              "JOIN (
        SELECT * FROM (VALUES #{locale_codes.map { "(?)" }.join(",")}) as Y (locale_code, locale_sort_column)
      ) as Y ON Y.locale_code = theme_fields.name",
              *locale_codes.map.with_index { |code, index| [code, index] },
            ),
          ).order("Y.locale_sort_column")
        }

  scope :find_first_locale_fields,
        ->(theme_ids, locale_codes) {
          find_by_theme_ids(theme_ids)
            .filter_locale_fields(locale_codes)
            .reorder("X.theme_sort_column", "Y.locale_sort_column")
            .select("DISTINCT ON (X.theme_sort_column) *")
        }

  def self.types
    @types ||=
      Enum.new(
        html: 0,
        scss: 1,
        theme_upload_var: 2,
        theme_color_var: 3, # No longer used
        theme_var: 4, # No longer used
        yaml: 5,
        js: 6,
      )
  end

  def self.theme_var_type_ids
    @theme_var_type_ids ||= [2]
  end

  def self.css_theme_type_ids
    @css_theme_type_ids ||= [0, 1]
  end

  def self.force_recompilation!
    find_each do |field|
      field.compiler_version = 0
      field.ensure_baked!
    end
  end

  validates :name,
            format: {
              with: /\A[a-z_][a-z0-9_-]*\z/i,
            },
            if: Proc.new { |field| ThemeField.theme_var_type_ids.include?(field.type_id) }

  belongs_to :theme

  def process_html(html)
    errors = []
    javascript_cache || build_javascript_cache

    errors << I18n.t("themes.errors.optimized_link") if contains_optimized_link?(html)

    js_compiler = ThemeJavascriptCompiler.new(theme_id, self.theme.name)

    doc = Nokogiri::HTML5.fragment(html)

    doc
      .css('script[type="text/x-handlebars"]')
      .each do |node|
        name = node["name"] || node["data-template-name"] || "broken"
        is_raw = name =~ /\.(raw|hbr)\z/
        hbs_template = node.inner_html

        begin
          if is_raw
            js_compiler.append_raw_template(name, hbs_template)
          else
            js_compiler.append_ember_template("discourse/templates/#{name}", hbs_template)
          end
        rescue ThemeJavascriptCompiler::CompileError => ex
          js_compiler.append_js_error("discourse/templates/#{name}", ex.message)
          errors << ex.message
        end

        node.remove
      end

    doc
      .css('script[type="text/discourse-plugin"]')
      .each_with_index do |node, index|
        version = node["version"]
        next if version.blank?

        initializer_name =
          "theme-field" + "-#{self.id}" + "-#{Theme.targets[self.target_id]}" +
            "-#{ThemeField.types[self.type_id]}" + "-script-#{index + 1}"
        begin
          js = <<~JS
          import { withPluginApi } from "discourse/lib/plugin-api";

          export default {
            name: #{initializer_name.inspect},
            after: "inject-objects",

            initialize() {
              withPluginApi(#{version.inspect}, (api) => {
                #{node.inner_html}
              });
            }
          };
        JS

          js_compiler.append_module(
            js,
            "discourse/initializers/#{initializer_name}",
            include_variables: true,
          )
        rescue ThemeJavascriptCompiler::CompileError => ex
          js_compiler.append_js_error("discourse/initializers/#{initializer_name}", ex.message)
          errors << ex.message
        end

        node.remove
      end

    doc
      .css("script")
      .each_with_index do |node, index|
        next unless inline_javascript?(node)
        js_compiler.append_raw_script(
          "_html/#{Theme.targets[self.target_id]}/#{name}_#{index + 1}.js",
          node.inner_html,
        )
        node.remove
      end

    settings_hash = theme.build_settings_hash
    if js_compiler.has_content? && settings_hash.present?
      js_compiler.prepend_settings(settings_hash)
    end
    javascript_cache.content = js_compiler.content
    javascript_cache.source_map = js_compiler.source_map
    javascript_cache.save!

    doc.add_child(<<~HTML.html_safe) if javascript_cache.content.present?
          <link rel="preload" href="#{javascript_cache.url}" as="script">
          <script defer src='#{javascript_cache.url}' data-theme-id='#{theme_id}'></script>
        HTML
    [doc.to_s, errors&.join("\n")]
  end

  def validate_svg_sprite_xml
    upload =
      begin
        Upload.find(self.upload_id)
      rescue StandardError
        nil
      end

    if Discourse.store.external?
      external_copy =
        begin
          Discourse.store.download(upload)
        rescue StandardError
          nil
        end
      path = external_copy.try(:path)
    else
      path = Discourse.store.path_for(upload)
    end

    error = nil

    begin
      content = File.read(path)
      Nokogiri.XML(content) { |config| config.options = Nokogiri::XML::ParseOptions::NOBLANKS }
    rescue => e
      error = "Error with #{self.name}: #{e.inspect}"
    end
    error
  end

  def raw_translation_data(internal: false)
    # Might raise ThemeTranslationParser::InvalidYaml
    ThemeTranslationParser.new(self, internal: internal).load
  end

  def translation_data(with_overrides: true, internal: false, fallback_fields: nil)
    fallback_fields ||= theme.theme_fields.filter_locale_fields(I18n.fallbacks[name])

    fallback_data =
      fallback_fields.each_with_index.map do |field, index|
        begin
          field.raw_translation_data(internal: internal)
        rescue ThemeTranslationParser::InvalidYaml
          # If this is the locale with the error, raise it.
          # If not, let the other theme_field raise the error when it processes itself
          raise if field.id == id
          {}
        end
      end

    # TODO: Deduplicate the fallback data in the same way as JSLocaleHelper#load_translations_merged
    #       this would reduce the size of the payload, without affecting functionality
    data = {}
    fallback_data.each { |hash| data.merge!(hash) }

    if with_overrides
      overrides = theme.translation_override_hash.deep_symbolize_keys
      data.deep_merge!(overrides)
    end

    data
  end

  def process_translation
    errors = []
    javascript_cache || build_javascript_cache
    js_compiler = ThemeJavascriptCompiler.new(theme_id, self.theme.name)
    begin
      data = translation_data

      js = <<~JS
        export default {
          name: "theme-#{theme_id}-translations",
          initialize() {
            /* Translation data for theme #{self.theme_id} (#{self.name})*/
            const data = #{data.to_json};

            for (let lang in data){
              let cursor = I18n.translations;
              for (let key of [lang, "js", "theme_translations"]){
                cursor = cursor[key] = cursor[key] || {};
              }
              cursor[#{self.theme_id}] = data[lang];
            }
          }
        };
      JS

      js_compiler.append_module(
        js,
        "discourse/pre-initializers/theme-#{theme_id}-translations",
        include_variables: false,
      )
    rescue ThemeTranslationParser::InvalidYaml => e
      errors << e.message
    end

    javascript_cache.content = js_compiler.content
    javascript_cache.source_map = js_compiler.source_map
    javascript_cache.save!
    doc = ""
    doc = <<~HTML.html_safe if javascript_cache.content.present?
          <link rel="preload" href="#{javascript_cache.url}" as="script">
          <script defer src='#{javascript_cache.url}' data-theme-id='#{theme_id}'></script>
        HTML
    [doc, errors&.join("\n")]
  end

  def validate_yaml!
    return unless self.name == "yaml"

    errors = []
    begin
      ThemeSettingsParser
        .new(self)
        .load do |name, default, type, opts|
          setting = ThemeSetting.new(name: name, data_type: type, theme: theme)
          translation_key = "themes.settings_errors"

          if setting.invalid?
            setting.errors.details.each_pair do |attribute, _errors|
              _errors.each do |hash|
                errors << I18n.t("#{translation_key}.#{attribute}_#{hash[:error]}", name: name)
              end
            end
          end

          errors << I18n.t("#{translation_key}.default_value_missing", name: name) if default.nil?

          if (min = opts[:min]) && (max = opts[:max])
            unless ThemeSetting.value_in_range?(default, (min..max), type)
              errors << I18n.t("#{translation_key}.default_out_range", name: name)
            end
          end

          unless ThemeSetting.acceptable_value_for_type?(default, type)
            errors << I18n.t("#{translation_key}.default_not_match_type", name: name)
          end
        end
    rescue ThemeSettingsParser::InvalidYaml => e
      errors << e.message
    end

    self.error = errors.join("\n").presence
  end

  def self.guess_type(name:, target:)
    if basic_targets.include?(target.to_s) && html_fields.include?(name.to_s)
      types[:html]
    elsif basic_targets.include?(target.to_s) && scss_fields.include?(name.to_s)
      types[:scss]
    elsif target.to_s == "extra_scss"
      types[:scss]
    elsif target.to_s == "extra_js"
      types[:js]
    elsif target.to_s == "settings" || target.to_s == "translations"
      types[:yaml]
    end
  end

  def self.html_fields
    @html_fields ||= %w[body_tag head_tag header footer after_header]
  end

  def self.scss_fields
    @scss_fields ||= %w[scss embedded_scss color_definitions]
  end

  def self.basic_targets
    @basic_targets ||= %w[common desktop mobile]
  end

  def basic_html_field?
    ThemeField.basic_targets.include?(Theme.targets[self.target_id].to_s) &&
      ThemeField.html_fields.include?(self.name)
  end

  def extra_js_field?
    Theme.targets[self.target_id] == :extra_js
  end

  def js_tests_field?
    Theme.targets[self.target_id] == :tests_js
  end

  def basic_scss_field?
    ThemeField.basic_targets.include?(Theme.targets[self.target_id].to_s) &&
      ThemeField.scss_fields.include?(self.name)
  end

  def extra_scss_field?
    Theme.targets[self.target_id] == :extra_scss
  end

  def settings_field?
    Theme.targets[:settings] == self.target_id
  end

  def translation_field?
    Theme.targets[:translations] == self.target_id
  end

  def svg_sprite_field?
    ThemeField.theme_var_type_ids.include?(self.type_id) &&
      self.name == SvgSprite.theme_sprite_variable_name
  end

  def ensure_baked!
    needs_baking = !self.value_baked || compiler_version != Theme.compiler_version
    return unless needs_baking

    if basic_html_field? || translation_field?
      self.value_baked, self.error =
        translation_field? ? process_translation : process_html(self.value)
      self.error = nil unless self.error.present?
      self.compiler_version = Theme.compiler_version
      DB.after_commit { CSP::Extension.clear_theme_extensions_cache! }
    elsif extra_js_field? || js_tests_field?
      self.error = nil
      self.value_baked = "baked"
      self.compiler_version = Theme.compiler_version
    elsif basic_scss_field?
      ensure_scss_compiles!
      DB.after_commit { Stylesheet::Manager.clear_theme_cache! }
    elsif settings_field?
      validate_yaml!
      DB.after_commit { CSP::Extension.clear_theme_extensions_cache! }
      DB.after_commit { SvgSprite.expire_cache }
      self.value_baked = "baked"
      self.compiler_version = Theme.compiler_version
    elsif svg_sprite_field?
      DB.after_commit { SvgSprite.expire_cache }
      self.error = validate_svg_sprite_xml
      self.value_baked = "baked"
      self.compiler_version = Theme.compiler_version
    end

    if self.will_save_change_to_value_baked? || self.will_save_change_to_compiler_version? ||
         self.will_save_change_to_error?
      self.update_columns(
        value_baked: value_baked,
        compiler_version: compiler_version,
        error: error,
      )
    end
  end

  def compile_scss(prepended_scss = nil)
    prepended_scss ||= Stylesheet::Importer.new({}).prepended_scss

    self.theme.with_scss_load_paths do |load_paths|
      Stylesheet::Compiler.compile(
        "#{prepended_scss} #{self.theme.scss_variables.to_s} #{self.value}",
        "#{Theme.targets[self.target_id]}.scss",
        theme: self.theme,
        load_paths: load_paths,
      )
    end
  end

  def compiled_css(prepended_scss)
    css, _source_map =
      begin
        compile_scss(prepended_scss)
      rescue SassC::SyntaxError => e
        # We don't want to raise a blocking error here
        # admin theme editor or discourse_theme CLI will show it nonetheless
        Rails.logger.error "SCSS compilation error: #{e.message}"
        ["", nil]
      end
    css
  end

  def ensure_scss_compiles!
    result = ["failed"]
    begin
      result = compile_scss
      if contains_optimized_link?(self.value)
        self.error = I18n.t("themes.errors.optimized_link")
      elsif contains_ember_css_selector?(self.value)
        self.error = I18n.t("themes.ember_selector_error")
      else
        self.error = nil unless error.nil?
      end
    rescue SassC::SyntaxError => e
      self.error = e.message unless self.destroyed?
    end
    self.compiler_version = Theme.compiler_version
    self.value_baked = Digest::SHA1.hexdigest(result.join(",")) # We don't use the compiled CSS here, we just use it to invalidate the stylesheet cache
  end

  def target_name
    Theme.targets[target_id].to_s
  end

  def contains_optimized_link?(text)
    OptimizedImage::URL_REGEX.match?(text)
  end

  def contains_ember_css_selector?(text)
    text.match(/#ember\d+|[.]ember-view/)
  end

  class ThemeFileMatcher
    OPTIONS = %i[name type target]
    # regex: used to match file names to fields (import).
    #        can contain named capture groups for name/type/target
    # canonical: a lambda which converts name/type/target
    #            to filename (export)
    # targets/names/types: can be nil if any value is allowed
    #                          single value
    #                          array of allowed values
    def initialize(regex:, canonical:, targets:, names:, types:)
      @allowed_values = {}
      @allowed_values[:names] = Array(names) if names
      @allowed_values[:targets] = Array(targets) if targets
      @allowed_values[:types] = Array(types) if types
      @canonical = canonical
      @regex = regex
    end

    def opts_from_filename(filename)
      match = @regex.match(filename)
      return false unless match
      hash = {}
      OPTIONS.each do |option|
        plural = :"#{option}s"
        hash[option] = @allowed_values[plural][0] if @allowed_values[plural]&.length == 1
        hash[option] = match[option] if hash[option].nil?
      end
      hash
    end

    def filename_from_opts(opts)
      is_match =
        OPTIONS.all? do |option|
          plural = :"#{option}s"
          next true if @allowed_values[plural] == nil # Allows any value
          next true if @allowed_values[plural].include?(opts[option]) # Value is allowed
        end
      is_match ? @canonical.call(opts) : nil
    end
  end

  FILE_MATCHERS = [
    ThemeFileMatcher.new(
      regex:
        %r{\A(?<target>(?:mobile|desktop|common))/(?<name>(?:head_tag|header|after_header|body_tag|footer))\.html\z},
      targets: %i[mobile desktop common],
      names: %w[head_tag header after_header body_tag footer],
      types: :html,
      canonical: ->(h) { "#{h[:target]}/#{h[:name]}.html" },
    ),
    ThemeFileMatcher.new(
      regex: %r{\A(?<target>(?:mobile|desktop|common))/(?:\k<target>)\.scss\z},
      targets: %i[mobile desktop common],
      names: "scss",
      types: :scss,
      canonical: ->(h) { "#{h[:target]}/#{h[:target]}.scss" },
    ),
    ThemeFileMatcher.new(
      regex: %r{\Acommon/embedded\.scss\z},
      targets: :common,
      names: "embedded_scss",
      types: :scss,
      canonical: ->(h) { "common/embedded.scss" },
    ),
    ThemeFileMatcher.new(
      regex: %r{\Acommon/color_definitions\.scss\z},
      targets: :common,
      names: "color_definitions",
      types: :scss,
      canonical: ->(h) { "common/color_definitions.scss" },
    ),
    ThemeFileMatcher.new(
      regex: %r{\A(?:scss|stylesheets)/(?<name>.+)\.scss\z},
      targets: :extra_scss,
      names: nil,
      types: :scss,
      canonical: ->(h) { "stylesheets/#{h[:name]}.scss" },
    ),
    ThemeFileMatcher.new(
      regex: %r{\Ajavascripts/(?<name>.+)\z},
      targets: :extra_js,
      names: nil,
      types: :js,
      canonical: ->(h) { "javascripts/#{h[:name]}" },
    ),
    ThemeFileMatcher.new(
      regex: %r{\Atest/(?<name>.+)\z},
      targets: :tests_js,
      names: nil,
      types: :js,
      canonical: ->(h) { "test/#{h[:name]}" },
    ),
    ThemeFileMatcher.new(
      regex: /\Asettings\.ya?ml\z/,
      names: "yaml",
      types: :yaml,
      targets: :settings,
      canonical: ->(h) { "settings.yml" },
    ),
    ThemeFileMatcher.new(
      regex: %r{\Alocales/(?<name>(?:#{I18n.available_locales.join("|")}))\.yml\z},
      names: I18n.available_locales.map(&:to_s),
      types: :yaml,
      targets: :translations,
      canonical: ->(h) { "locales/#{h[:name]}.yml" },
    ),
    ThemeFileMatcher.new(
      regex: /(?!)/, # Never match uploads by filename, they must be named in about.json
      names: nil,
      types: :theme_upload_var,
      targets: :common,
      canonical: ->(h) { "assets/#{h[:name]}#{File.extname(h[:filename])}" },
    ),
  ]

  # For now just work for standard fields
  def file_path
    FILE_MATCHERS.each do |matcher|
      if filename =
           matcher.filename_from_opts(
             target: target_name.to_sym,
             name: name,
             type: ThemeField.types[type_id],
             filename: upload&.original_filename,
           )
        return filename
      end
    end
    nil # Not a file (e.g. a theme variable/color)
  end

  def self.opts_from_file_path(filename)
    FILE_MATCHERS.each do |matcher|
      if opts = matcher.opts_from_filename(filename)
        return opts
      end
    end
    nil
  end

  def dependent_fields
    if extra_scss_field?
      return(
        theme.theme_fields.where(
          target_id: ThemeField.basic_targets.map { |t| Theme.targets[t.to_sym] },
          name: ThemeField.scss_fields,
        )
      )
    elsif settings_field?
      return(
        theme.theme_fields.where(
          target_id: ThemeField.basic_targets.map { |t| Theme.targets[t.to_sym] },
          name: ThemeField.scss_fields + ThemeField.html_fields,
        )
      )
    end
    ThemeField.none
  end

  def invalidate_baked!
    update_column(:value_baked, nil)
    dependent_fields.update_all(value_baked: nil)
  end

  before_save do
    if (will_save_change_to_value? || will_save_change_to_upload_id?) &&
         !will_save_change_to_value_baked?
      self.value_baked = nil
    end
    if upload && upload.extension == "js"
      if will_save_change_to_upload_id? || !javascript_cache
        javascript_cache ||= build_javascript_cache
        javascript_cache.content = upload.content
      end
    end
  end

  after_save { dependent_fields.each(&:invalidate_baked!) }

  after_destroy { DB.after_commit { SvgSprite.expire_cache } if svg_sprite_field? }

  private

  JAVASCRIPT_TYPES = %w[text/javascript application/javascript application/ecmascript]

  def inline_javascript?(node)
    if node["src"].present?
      false
    elsif node["type"].present?
      JAVASCRIPT_TYPES.include?(node["type"].downcase)
    else
      true
    end
  end
end

# == Schema Information
#
# Table name: theme_fields
#
#  id               :integer          not null, primary key
#  theme_id         :integer          not null
#  target_id        :integer          not null
#  name             :string(255)      not null
#  value            :text             not null
#  value_baked      :text
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  compiler_version :string(50)       default("0"), not null
#  error            :string
#  upload_id        :integer
#  type_id          :integer          default(0), not null
#
# Indexes
#
#  theme_field_unique_index  (theme_id,target_id,type_id,name) UNIQUE
#
