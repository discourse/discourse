# frozen_string_literal: true

require "colored2"
require "yaml"
require "active_support"
require "active_support/core_ext/array/extract_options"
require "active_support/core_ext/hash/keys"
require "active_support/core_ext/object/blank"
require_relative "../lib/enum"
require_relative "../lib/upcoming_changes"
require_relative "../lib/site_settings/yaml_loader"

class UpcomingChangesLinter
  def initialize(filenames_or_patterns)
    @filenames = filenames_or_patterns.flat_map { |fp| Dir[fp] }
  end

  def run
    has_errors = false

    @filenames.each do |filename|
      validator = UpcomingChangesFileValidator.new(filename)

      if validator.has_errors?
        validator.print_errors
        has_errors = true
      end
    end

    exit 1 if has_errors
  end
end

class UpcomingChangesFileValidator
  CORE_SETTINGS_FILE = File.expand_path("../config/site_settings.yml", __dir__)

  ALLOWED_KEYS = %i[
    status
    impact
    learn_more_url
    allow_enabled_for
    group_setting
    body_class
    permanent_warning
    hide_settings
    requires_plugin_enabled
  ]
  REQUIRED_KEYS = %i[status impact]
  BOOLEAN_KEYS = %i[body_class permanent_warning requires_plugin_enabled]
  IMPACT_TYPES = %w[feature other site_setting_default]
  IMPACT_ROLES = UpcomingChanges::ROLE_GROUP_KEYS.keys.map(&:to_s)
  ALLOW_ENABLED_FOR_VALUES = %w[everyone logged_in_users staff specific_groups]
  LEARN_MORE_URL_FORMAT = %r{\Ahttps://meta\.discourse\.org/t/-/\d+\z}

  attr_reader :errors

  def initialize(filename, core_settings_file: CORE_SETTINGS_FILE)
    @filename = filename
    @core_settings_file = core_settings_file
    @errors = []
  end

  def has_errors?
    SiteSettings::YamlLoader
      .new(@filename)
      .load do |_category, setting_name, default, opts|
        next if opts[:upcoming_change].blank?
        validate(setting_name.to_s, default, opts)
      end

    @errors.any?
  rescue StandardError => e
    @errors << "Failed to parse #{@filename}: #{e.message}"
    true
  end

  def print_errors
    puts "", "Errors in #{@filename}".red
    @errors.each { |error| puts "  * #{error}" }
  end

  private

  def validate(name, default, opts)
    metadata = opts[:upcoming_change]
    error = ->(message) { @errors << "#{name} #{message}" }

    error["must set `hidden: true`"] if opts[:hidden] != true
    error["must set `client: true`"] if opts[:client] != true
    error["must set `default: false`"] if default != false

    unsupported_keys = metadata.keys - ALLOWED_KEYS
    if unsupported_keys.any?
      error[
        "has unsupported upcoming_change keys: #{unsupported_keys.join(", ")}. Allowed keys: #{ALLOWED_KEYS.join(", ")}"
      ]
    end

    missing_keys = REQUIRED_KEYS - metadata.keys
    if missing_keys.any?
      error["is missing required upcoming_change keys: #{missing_keys.join(", ")}"]
    end

    status = metadata[:status]&.to_s&.to_sym
    valid_statuses = UpcomingChanges.statuses.keys
    if metadata.key?(:status) && !valid_statuses.include?(status)
      error[
        "has invalid upcoming_change status #{status.inspect}. Valid statuses: #{valid_statuses.join(", ")}"
      ]
    end

    validate_impact(metadata[:impact], error)

    if status != :conceptual
      learn_more_url = metadata[:learn_more_url]
      if learn_more_url.blank?
        error["must set `upcoming_change.learn_more_url` when status is not `conceptual`"]
      elsif !learn_more_url.to_s.match?(LEARN_MORE_URL_FORMAT)
        error[
          "upcoming_change.learn_more_url must match https://meta.discourse.org/t/-/NNNN, do not include the topic slug"
        ]
      end
    end

    validate_group_setting(metadata, error) if metadata.key?(:group_setting)
    validate_allow_enabled_for(metadata[:allow_enabled_for], error)

    BOOLEAN_KEYS.each do |key|
      value = metadata[key]
      if !value.nil? && ![true, false].include?(value)
        error["`upcoming_change.#{key}` must be a boolean"]
      end
    end

    if !metadata[:requires_plugin_enabled].nil? && !plugin_dir
      error["sets `upcoming_change.requires_plugin_enabled` but is not owned by a plugin"]
    end

    # A plugin's own enabled setting would otherwise be gated on itself and could never be turned on.
    if name == plugin_enabled_site_setting && metadata[:requires_plugin_enabled] != false
      error[
        "is its plugin's own `enabled_site_setting` and must set `upcoming_change.requires_plugin_enabled: false`, otherwise the change gates itself"
      ]
    end

    validate_hide_settings(metadata[:hide_settings], error)
  end

  def validate_impact(impact, error)
    impact_parts = impact.is_a?(String) ? impact.split(",") : []

    if impact_parts.length != 2
      error["must set upcoming_change.impact as `type,role`, got #{impact.inspect}"]
      return
    end

    impact_type, impact_role = impact_parts

    if !IMPACT_TYPES.include?(impact_type)
      error[
        "has invalid upcoming_change impact type #{impact_type.inspect}. Valid types: #{IMPACT_TYPES.join(", ")}"
      ]
    end

    if !IMPACT_ROLES.include?(impact_role)
      error[
        "has invalid upcoming_change impact role #{impact_role.inspect}. Valid roles: #{IMPACT_ROLES.join(", ")}"
      ]
    end
  end

  def validate_group_setting(metadata, error)
    group_setting = metadata[:group_setting]

    error["`upcoming_change.group_setting` must name a group-list setting"] if group_setting.blank?

    if metadata.key?(:allow_enabled_for)
      error["may not combine `group_setting` and `allow_enabled_for`"]
    end

    linked_setting = linkable_settings[group_setting.to_s]

    error["must reference a core setting or a setting from its own plugin"] if linked_setting.nil?

    if linked_setting&.dig(:type) != "group_list"
      error["`upcoming_change.group_setting` must reference a group-list setting"]
    end
  end

  def validate_allow_enabled_for(allow_enabled_for, error)
    return if allow_enabled_for.blank?

    allow_strings = Array(allow_enabled_for).map(&:to_s)
    invalid_values = allow_strings - ALLOW_ENABLED_FOR_VALUES

    error["`upcoming_change.allow_enabled_for` must be an array"] if !allow_enabled_for.is_a?(Array)

    if invalid_values.any?
      error[
        "`upcoming_change.allow_enabled_for` contains invalid values: #{invalid_values.join(", ")}. Valid values: #{ALLOW_ENABLED_FOR_VALUES.join(", ")}"
      ]
    end

    %w[everyone logged_in_users].each do |fixed_audience|
      if allow_strings.include?(fixed_audience) && allow_strings != [fixed_audience]
        error[
          "`upcoming_change.allow_enabled_for` may not combine `#{fixed_audience}` with other values"
        ]
      end
    end
  end

  def validate_hide_settings(hide_settings, error)
    return if hide_settings.blank?

    error["`upcoming_change.hide_settings` must be an array"] if !hide_settings.is_a?(Array)

    unknown_settings = Array(hide_settings).map(&:to_s) - linkable_settings.keys
    if unknown_settings.any?
      error[
        "`upcoming_change.hide_settings` references unknown site settings: #{unknown_settings.join(", ")}"
      ]
    end
  end

  def plugin_dir
    return @plugin_dir if defined?(@plugin_dir)
    dir = File.expand_path("../..", @filename)
    @plugin_dir = File.exist?(File.join(dir, "plugin.rb")) ? dir : nil
  end

  def plugin_enabled_site_setting
    return if !plugin_dir
    @plugin_enabled_site_setting ||=
      File.read(File.join(plugin_dir, "plugin.rb"))[/enabled_site_setting\s+:(\w+)/, 1]
  end

  def linkable_settings
    @linkable_settings ||=
      begin
        files = [@core_settings_file]
        files << File.join(plugin_dir, "config/settings.yml") if plugin_dir

        files.each_with_object({}) do |file, settings|
          next if !File.exist?(file)
          SiteSettings::YamlLoader
            .new(file)
            .load { |_category, setting_name, _default, opts| settings[setting_name.to_s] = opts }
        end
      end
  end
end

UpcomingChangesLinter.new(ARGV).run if $PROGRAM_NAME == __FILE__
