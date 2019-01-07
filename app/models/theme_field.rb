require_dependency 'theme_settings_parser'
require_dependency 'theme_translation_parser'

class ThemeField < ActiveRecord::Base

  belongs_to :upload
  has_one :javascript_cache, dependent: :destroy

  scope :find_by_theme_ids, ->(theme_ids) {
    return none unless theme_ids.present?

    where(theme_id: theme_ids)
      .joins(
        "JOIN (
          SELECT #{theme_ids.map.with_index { |id, idx| "#{id.to_i} AS theme_id, #{idx} AS theme_sort_column" }.join(" UNION ALL SELECT ")}
        ) as X ON X.theme_id = theme_fields.theme_id")
      .order("theme_sort_column")
  }

  scope :find_locale_fields, ->(theme_ids, locale_codes) {
    return none unless theme_ids.present? && locale_codes.present?

    find_by_theme_ids(theme_ids)
      .where(target_id: Theme.targets[:translations], name: locale_codes)
      .joins(self.sanitize_sql_array([
        "JOIN (
          SELECT * FROM (VALUES #{locale_codes.map { "(?)" }.join(",")}) as Y (locale_code, locale_sort_column)
        ) as Y ON Y.locale_code = theme_fields.name",
        *locale_codes.map.with_index { |code, index| [code, index] }
      ]))
      .reorder("X.theme_sort_column", "Y.locale_sort_column")
  }

  scope :find_first_locale_fields, ->(theme_ids, locale_codes) {
    find_locale_fields(theme_ids, locale_codes)
      .select("DISTINCT ON (X.theme_sort_column) *")
  }

  def self.types
    @types ||= Enum.new(html: 0,
                        scss: 1,
                        theme_upload_var: 2,
                        theme_color_var: 3,
                        theme_var: 4,
                        yaml: 5)
  end

  def self.theme_var_type_ids
    @theme_var_type_ids ||= [2, 3, 4]
  end

  def self.force_recompilation!
    find_each do |field|
      field.compiler_version = 0
      field.ensure_baked!
    end
  end

  validates :name, format: { with: /\A[a-z_][a-z0-9_-]*\z/i },
                   if: Proc.new { |field| ThemeField.theme_var_type_ids.include?(field.type_id) }

  COMPILER_VERSION = 6

  belongs_to :theme

  def settings(source)

    settings = {}

    theme.cached_settings.each do |k, v|
      if source.include?("settings.#{k}")
        settings[k] = v
      end
    end

    if settings.length > 0
      "let settings = #{settings.to_json};"
    else
      ""
    end
  end

  def transpile(es6_source, version)
    template = Tilt::ES6ModuleTranspilerTemplate.new {}
    wrapped = <<PLUGIN_API_JS
if ('Discourse' in window && typeof Discourse._registerPluginCode === 'function') {
Discourse._registerPluginCode('#{version}', api => {
  #{settings(es6_source)}
  let themePrefix = "theme_translations.#{self.theme_id}.";
  #{es6_source}
});
}
PLUGIN_API_JS

    template.babel_transpile(wrapped)
  end

  def process_html(html)
    errors = nil
    javascript_cache || build_javascript_cache
    javascript_cache.content = ''

    doc = Nokogiri::HTML.fragment(html)
    doc.css('script[type="text/x-handlebars"]').each do |node|
      name = node["name"] || node["data-template-name"] || "broken"

      is_raw = name =~ /\.raw$/
      setting_helpers = ''
      theme.cached_settings.each do |k, v|
        val = v.is_a?(String) ? "\"#{v.gsub('"', "\\u0022")}\"" : v
        setting_helpers += "{{theme-injector #{is_raw ? "" : "context=this"} parent=\"themeSettings\" key=\"#{k}\" value=#{val}}}\n"
      end
      theme_prefix = "theme_translations.#{self.theme_id}."
      setting_helpers += "{{theme-injector #{is_raw ? "" : "context=this"} key=\"theme-prefix\" value=\"#{theme_prefix}\"}}\n"
      hbs_template = setting_helpers + node.inner_html

      if is_raw
        template = "requirejs('discourse-common/lib/raw-handlebars').template(#{Barber::Precompiler.compile(hbs_template)})"
        javascript_cache.content << <<COMPILED
          (function() {
            if ('Discourse' in window) {
              Discourse.RAW_TEMPLATES[#{name.sub(/\.raw$/, '').inspect}] = #{template};
            }
          })();
COMPILED
      else
        template = "Ember.HTMLBars.template(#{Barber::Ember::Precompiler.compile(hbs_template)})"
        javascript_cache.content << <<COMPILED
          (function() {
            if ('Em' in window) {
              Ember.TEMPLATES[#{name.inspect}] = #{template};
            }
          })();
COMPILED
      end

      node.remove
    end

    doc.css('script[type="text/discourse-plugin"]').each do |node|
      if node['version'].present?
        begin
          javascript_cache.content << transpile(node.inner_html, node['version'])
        rescue MiniRacer::RuntimeError => ex
          javascript_cache.content << "console.error('Theme Transpilation Error:', #{ex.message.inspect});"

          errors ||= []
          errors << ex.message
        end

        node.remove
      end
    end

    doc.css('script').each do |node|
      next unless inline_javascript?(node)

      javascript_cache.content << node.inner_html
      javascript_cache.content << "\n"
      node.remove
    end

    javascript_cache.save!

    doc.add_child("<script src='#{javascript_cache.url}'></script>") if javascript_cache.content.present?
    [doc.to_s, errors&.join("\n")]
  end

  def raw_translation_data
    # Might raise ThemeTranslationParser::InvalidYaml
    ThemeTranslationParser.new(self).load
  end

  def translation_data(with_overrides: true)
    fallback_fields = theme.theme_fields.find_locale_fields([theme.id], I18n.fallbacks[name])

    fallback_data = fallback_fields.each_with_index.map do |field, index|
      begin
        field.raw_translation_data
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
    overrides = theme.translation_override_hash.deep_symbolize_keys
    data.deep_merge!(overrides) if with_overrides
    data
  end

  def process_translation
    errors = []
    javascript_cache || build_javascript_cache
    javascript_cache.content = ''
    begin
      data = translation_data

      js = <<~JS
        /* Translation data for theme #{self.theme_id} (#{self.name})*/
        const data = #{data.to_json};

        for (let lang in data){
          let cursor = I18n.translations;
          for (let key of [lang, "js", "theme_translations"]){
            cursor = cursor[key] = cursor[key] || {};
          }
          cursor[#{self.theme_id}] = data[lang];
        }
      JS

      javascript_cache.content << transpile(js, 0)
    rescue ThemeTranslationParser::InvalidYaml => e
      errors << e.message
    end

    javascript_cache.save!
    doc = ""
    doc = "<script src='#{javascript_cache.url}'></script>" if javascript_cache.content.present?
    [doc, errors&.join("\n")]
  end

  def validate_yaml!
    return unless self.name == "yaml"

    errors = []
    begin
      ThemeSettingsParser.new(self).load do |name, default, type, opts|
        setting = ThemeSetting.new(name: name, data_type: type, theme: theme)
        translation_key = "themes.settings_errors"

        if setting.invalid?
          setting.errors.details.each_pair do |attribute, _errors|
            _errors.each do |hash|
              errors << I18n.t("#{translation_key}.#{attribute}_#{hash[:error]}", name: name)
            end
          end
        end

        if default.nil?
          errors << I18n.t("#{translation_key}.default_value_missing", name: name)
        end

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
    if html_fields.include?(name.to_s)
      types[:html]
    elsif scss_fields.include?(name.to_s)
      types[:scss]
    elsif name.to_s == "yaml" || target.to_s == "translations"
      types[:yaml]
    end
  end

  def self.html_fields
    @html_fields ||= %w(body_tag head_tag header footer after_header)
  end

  def self.scss_fields
    @scss_fields ||= %w(scss embedded_scss)
  end

  def ensure_baked!
    if ThemeField.html_fields.include?(self.name) || translation = Theme.targets[:translations] == self.target_id
      if !self.value_baked || compiler_version != COMPILER_VERSION
        self.value_baked, self.error = translation ? process_translation : process_html(self.value)
        self.compiler_version = COMPILER_VERSION

        if self.will_save_change_to_value_baked? ||
           self.will_save_change_to_compiler_version? ||
           self.will_save_change_to_error?

          self.update_columns(value_baked: value_baked,
                              compiler_version: compiler_version,
                              error: error)
        end
      end
    end
  end

  def ensure_scss_compiles!
    if ThemeField.scss_fields.include?(self.name)
      begin
        Stylesheet::Compiler.compile("@import \"theme_variables\"; @import \"theme_field\";",
                                     "theme.scss",
                                     theme_field: self.value.dup,
                                     theme: self.theme
                                    )
        self.error = nil unless error.nil?
      rescue SassC::SyntaxError => e
        self.error = e.message unless self.destroyed?
      end

      if will_save_change_to_error?
        update_columns(error: self.error)
      end
    end
  end

  def target_name
    Theme.targets.invert[target_id].to_s
  end

  before_save do
    validate_yaml!

    if will_save_change_to_value? && !will_save_change_to_value_baked?
      self.value_baked = nil
    end
  end

  after_commit do
    ensure_baked!
    ensure_scss_compiles!
    theme.clear_cached_settings!

    Stylesheet::Manager.clear_theme_cache! if self.name.include?("scss")
    CSP::Extension.clear_theme_extensions_cache! if name == 'yaml'

    # TODO message for mobile vs desktop
    MessageBus.publish "/header-change/#{theme.id}", self.value if theme && self.name == "header"
    MessageBus.publish "/footer-change/#{theme.id}", self.value if theme && self.name == "footer"
  end

  private

  JAVASCRIPT_TYPES = %w(
    text/javascript
    application/javascript
    application/ecmascript
  )

  def inline_javascript?(node)
    if node['src'].present?
      false
    elsif node['type'].present?
      JAVASCRIPT_TYPES.include?(node['type'].downcase)
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
#  name             :string(30)       not null
#  value            :text             not null
#  value_baked      :text
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  compiler_version :integer          default(0), not null
#  error            :string
#  upload_id        :integer
#  type_id          :integer          default(0), not null
#
# Indexes
#
#  theme_field_unique_index  (theme_id,target_id,type_id,name) UNIQUE
#
