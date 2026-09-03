# frozen_string_literal: true

module SiteSettings
end

class SiteSettings::GroupListConstraints
  SchemaError = SiteSettings::GroupRefs::SchemaError

  RULE_KEYS = %i[at_least_one mandatory disallowed].freeze

  attr_reader :at_least_one, :at_least_one_message, :mandatory_ids, :disallowed_ids

  def self.from_opts!(opts, name:, group_type:, lenient: false)
    return compile_non_group(opts, name) unless group_type

    block_declared = opts.key?(:constraints)
    block = opts.delete(:constraints)
    mandatory_declared = opts.key?(:mandatory_values)
    mandatory_value = opts.delete(:mandatory_values)
    disallowed_declared = opts.key?(:disallowed_groups)
    disallowed_value = opts.delete(:disallowed_groups)
    validator_declared = opts[:validator] == "AtLeastOneGroupValidator"
    opts.delete(:validator) if validator_declared

    legacy_declared = mandatory_declared || disallowed_declared || validator_declared
    errors = []

    block_values = nil
    if block_declared
      if legacy_declared
        legacy_names = []
        legacy_names << "mandatory_values" if mandatory_declared
        legacy_names << "disallowed_groups" if disallowed_declared
        legacy_names << "validator" if validator_declared
        errors << "#{name}: constraints cannot be combined with legacy #{legacy_names.join(", ")}"
      else
        block_values, block_errors = compile_block(block, name)
        errors.concat(block_errors)
      end
    end

    legacy_values, legacy_errors =
      compile_legacy(
        mandatory_value,
        disallowed_value,
        validator_declared,
        mandatory_declared,
        disallowed_declared,
        name,
      )
    errors.concat(legacy_errors)

    values = block_values || legacy_values || empty_values
    values = empty_values if lenient && block_declared && !block_values && !legacy_declared

    [new(**values), errors]
  rescue StandardError => error
    [new(**empty_values), ["#{name}: #{error.message}"]]
  end

  def self.compile_non_group(opts, name)
    errors = []
    if opts.key?(:constraints)
      errors << "#{name}: constraints are only valid for group_list settings"
    end
    if opts.key?(:disallowed_groups)
      errors << "#{name}: disallowed_groups is only valid for group_list settings"
    end
    [nil, errors]
  end
  private_class_method :compile_non_group

  def self.compile_block(block, name)
    return nil, ["#{name}: constraints must be a map"] unless block.is_a?(Hash)

    errors = []
    unknown_keys = block.keys - RULE_KEYS
    unknown_keys.each do |key|
      suggestion =
        DidYouMean::SpellChecker.new(dictionary: RULE_KEYS.map(&:to_s)).correct(key.to_s).first
      message = "#{name}: unknown constraints key #{key.inspect}"
      message += "; did you mean #{suggestion.inspect}?" if suggestion
      errors << message
    end

    at_least_one = false
    at_least_one_message = nil
    if block.key?(:at_least_one)
      value = block[:at_least_one]
      case value
      when true, false
        at_least_one = value
      when Hash
        extra_keys = value.keys - [:message]
        extra_keys.each { |key| errors << "#{name}: unknown at_least_one key #{key.inspect}" }
        if value.key?(:message) && !value[:message].is_a?(String)
          errors << "#{name}: at_least_one message must be a String"
        elsif extra_keys.empty? && !value.key?(:message)
          errors << "#{name}: at_least_one message must be a String"
        end
        if extra_keys.empty? && value[:message].is_a?(String)
          at_least_one = true
          at_least_one_message = value[:message]
        end
      else
        errors << "#{name}: at_least_one must be true, false, or a message map"
      end
    end

    mandatory_declared = block.key?(:mandatory)
    disallowed_declared = block.key?(:disallowed)
    mandatory_ids =
      (
        if mandatory_declared
          compile_rule_array(block[:mandatory], :mandatory, name, errors)
        else
          []
        end
      )
    disallowed_ids =
      (
        if disallowed_declared
          compile_rule_array(block[:disallowed], :disallowed, name, errors)
        else
          []
        end
      )

    if mandatory_ids && disallowed_ids
      (mandatory_ids & disallowed_ids).each do |id|
        group_name = Group::AUTO_GROUP_IDS[id]
        token = group_name ? "#{group_name} (#{id})" : id.to_s
        errors << "#{name}: group #{token} is both mandatory and disallowed"
      end
    end

    return nil, errors if errors.any?

    [
      {
        at_least_one: at_least_one,
        at_least_one_message: at_least_one_message,
        mandatory_ids: mandatory_ids || [],
        disallowed_ids: disallowed_ids || [],
        mandatory_values: mandatory_declared ? mandatory_ids.join("|") : nil,
        disallowed_groups: disallowed_declared ? disallowed_ids.join("|") : nil,
        strict: true,
      },
      [],
    ]
  end
  private_class_method :compile_block

  def self.compile_rule_array(value, key, name, errors)
    unless value.is_a?(Array)
      errors << "#{name}: constraints #{key} must be an Array"
      return
    end

    SiteSettings::GroupRefs.resolve_ids(value, context: "#{name} constraints #{key}")
  rescue SchemaError => error
    errors << error.message
    nil
  end
  private_class_method :compile_rule_array

  def self.compile_legacy(
    mandatory_value,
    disallowed_value,
    at_least_one,
    mandatory_declared,
    disallowed_declared,
    name
  )
    return nil, [] unless mandatory_declared || disallowed_declared || at_least_one

    mandatory_ids =
      if mandatory_declared
        SiteSettings::GroupRefs.resolve_ids(mandatory_value, context: "#{name} mandatory_values")
      else
        []
      end
    disallowed_ids =
      if disallowed_declared
        SiteSettings::GroupRefs.resolve_ids(disallowed_value, context: "#{name} disallowed_groups")
      else
        []
      end

    [
      {
        at_least_one: at_least_one,
        at_least_one_message: nil,
        mandatory_ids: mandatory_ids,
        disallowed_ids: disallowed_ids,
        mandatory_values: mandatory_declared ? mandatory_ids.join("|") : nil,
        disallowed_groups: disallowed_declared ? disallowed_ids.join("|") : nil,
        strict: false,
      },
      [],
    ]
  rescue SchemaError => error
    [nil, [error.message]]
  end
  private_class_method :compile_legacy

  def self.empty_values
    {
      at_least_one: false,
      at_least_one_message: nil,
      mandatory_ids: [],
      disallowed_ids: [],
      mandatory_values: nil,
      disallowed_groups: nil,
      strict: false,
    }
  end
  private_class_method :empty_values

  def initialize(
    at_least_one:,
    at_least_one_message:,
    mandatory_ids:,
    disallowed_ids:,
    mandatory_values:,
    disallowed_groups:,
    strict:
  )
    @at_least_one = at_least_one
    @at_least_one_message = at_least_one_message&.dup&.freeze
    @mandatory_ids = mandatory_ids.dup.freeze
    @disallowed_ids = disallowed_ids.dup.freeze
    @mandatory_values = mandatory_values&.dup&.freeze
    @disallowed_groups = disallowed_groups&.dup&.freeze
    @strict = strict
    freeze
  end
  private_class_method :new

  def strict?
    @strict
  end

  def mandatory_values
    @mandatory_values
  end

  def disallowed_groups
    @disallowed_groups
  end

  def normalize_ids(ids)
    (@mandatory_ids | ids.map { |id| Integer(id) }) - @disallowed_ids
  end

  def normalize(value)
    ids, = integer_ids(value)
    normalize_ids(ids).join("|")
  end

  def normalize!(value, name:)
    ids, invalid = integer_ids(value)
    if invalid.any?
      message =
        I18n.t("site_settings.errors.invalid_group_ids", ids: invalid.map(&:to_s).join(", "))
      raise Discourse::InvalidParameters, "#{name}: #{message}"
    end

    normalize_ids(ids).join("|")
  end

  def errors_for(value)
    normalized_ids = normalize(value).split("|").filter_map { |id| integer_token(id) }
    errors = []

    if @at_least_one && normalized_ids.empty?
      errors << I18n.t(@at_least_one_message || "site_settings.errors.at_least_one_group_required")
    end

    unknown_ids = normalized_ids - Group::AUTO_GROUPS.values
    if unknown_ids.any? && !GlobalSetting.skip_db?
      existing_ids = Group.where(id: unknown_ids).pluck(:id)
      missing_ids = unknown_ids - existing_ids
      if missing_ids.any?
        errors << I18n.t("site_settings.errors.unknown_group_ids", ids: missing_ids.join(", "))
      end
    end

    errors
  end

  def validate!(value, name:)
    errors = errors_for(value)
    raise Discourse::InvalidParameters, "#{name}: #{errors.join(" ")}" if errors.any?
  end

  def validate_default!(default, name:)
    ids, = integer_ids(default)
    if strict?
      details = []

      missing_mandatory = @mandatory_ids - ids
      details << "missing mandatory ids #{missing_mandatory.join(", ")}" if missing_mandatory.any?

      included_disallowed = ids & @disallowed_ids
      if included_disallowed.any?
        details << "contains disallowed ids #{included_disallowed.join(", ")}"
      end

      if @at_least_one && normalize_ids(ids).empty?
        details << "is empty while at_least_one is declared"
      end

      raise SchemaError, "#{name}: default #{details.join(" and ")}" if details.any?
    end

    normalize(default)
  end

  def ==(other)
    other.instance_of?(self.class) &&
      [at_least_one, at_least_one_message, mandatory_ids, disallowed_ids] ==
        [other.at_least_one, other.at_least_one_message, other.mandatory_ids, other.disallowed_ids]
  end

  def marshal_dump
    {
      at_least_one: @at_least_one,
      at_least_one_message: @at_least_one_message,
      mandatory_ids: @mandatory_ids,
      disallowed_ids: @disallowed_ids,
      mandatory_values: @mandatory_values,
      disallowed_groups: @disallowed_groups,
      strict: @strict,
    }
  end

  def marshal_load(values)
    initialize(**values)
  end

  private

  def integer_ids(value)
    tokens =
      case value
      when nil
        []
      when String
        value.split("|", -1)
      when Array
        value
      else
        [value]
      end

    ids = []
    invalid = []
    tokens.each do |token|
      next if token.nil? || (token.is_a?(String) && token.strip.empty?)

      id = integer_token(token)
      id ? ids << id : invalid << token
    end
    [ids.uniq, invalid]
  end

  def integer_token(token)
    return token if token.is_a?(Integer)
    return unless token.is_a?(String)

    stripped = token.strip
    Integer(stripped, 10) if stripped.match?(/\A[+-]?\d+\z/)
  end
end
