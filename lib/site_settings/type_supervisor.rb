# frozen_string_literal: true

module SiteSettings
end

class SiteSettings::TypeSupervisor
  include SiteSettings::Validations

  CONSUMED_OPTS = %i[
    enum
    choices
    type
    validator
    min
    max
    regex
    hidden
    regex_error
    allow_any
    list_type
    textarea
    json_schema
    requires_confirmation
  ].freeze
  VALIDATOR_OPTS = %i[min max regex hidden regex_error json_schema].freeze

  # For plugins, so they can tell if a feature is supported
  SUPPORTED_TYPES = %i[email username list enum].freeze

  REQUIRES_CONFIRMATION_TYPES = { simple: "simple", user_option: "user_option" }.freeze

  def self.types
    @types ||=
      Enum.new(
        string: 1,
        time: 2,
        integer: 3,
        float: 4,
        bool: 5,
        null: 6,
        enum: 7,
        list: 8,
        url_list: 9,
        host_list: 10,
        category_list: 11,
        value_list: 12,
        regex: 13,
        email: 14,
        username: 15,
        category: 16,
        uploaded_image_list: 17,
        upload: 18,
        group: 19,
        group_list: 20,
        tag_list: 21,
        color: 22,
        simple_list: 23,
        emoji_list: 24,
        html_deprecated: 25,
        tag_group_list: 26,
        file_size_restriction: 27,
      )
  end

  def self.parse_value_type(val)
    case val
    when NilClass
      self.types[:null]
    when String
      self.types[:string]
    when Integer
      self.types[:integer]
    when Float
      self.types[:float]
    when TrueClass, FalseClass
      self.types[:bool]
    else
      raise ArgumentError.new :val
    end
  end

  def self.supported_types
    SUPPORTED_TYPES
  end

  def initialize(defaults_provider)
    @defaults_provider = defaults_provider
    @enums = {}
    @static_types = {}
    @choices = {}
    @validators = {}
    @types = {}
    @allow_any = {}
    @list_type = {}
    @textareas = {}
    @json_schemas = {}
  end

  def load_setting(name_arg, opts = {})
    name = name_arg.to_sym

    @textareas[name] = opts[:textarea] if opts[:textarea]

    @json_schemas[name] = opts[:json_schema].constantize if opts[:json_schema]

    if (enum = opts[:enum])
      @enums[name] = enum.is_a?(String) ? enum.constantize : enum
      opts[:type] ||= :enum
    end

    if (new_choices = opts[:choices])
      new_choices = eval(new_choices) if new_choices.is_a?(String) # rubocop:disable Security/Eval

      if @choices.has_key?(name)
        @choices[name].concat(new_choices)
      else
        @choices[name] = new_choices
      end
    end

    if (type = opts[:type])
      @static_types[name] = type.to_sym

      if type.to_sym == :list
        @allow_any[name] = opts[:allow_any] == false ? false : true
        @list_type[name] = opts[:list_type] if opts[:list_type]
      end
    end
    @types[name] = get_data_type(name, @defaults_provider[name])

    opts[:validator] = opts[:validator].try(:constantize)
    if (validator_type = (opts[:validator] || validator_for(@types[name])))
      validator_opts = opts.slice(*VALIDATOR_OPTS)
      validator_opts[:name] = name
      @validators[name] = { class: validator_type, opts: validator_opts }
    end
  end

  def to_rb_value(name, value, override_type = nil)
    name = name.to_sym
    @types[name] = (@types[name] || get_data_type(name, value))
    type = (override_type || @types[name])

    case type
    when self.class.types[:float]
      value.to_f
    when self.class.types[:integer]
      value.to_i
    when self.class.types[:file_size_restriction]
      value.to_i
    when self.class.types[:bool]
      value == true || value == "t" || value == "true"
    when self.class.types[:null]
      nil
    when self.class.types[:enum]
      @defaults_provider[name].is_a?(Integer) ? value.to_i : value.to_s
    when self.class.types[:string]
      value.to_s
    else
      return value if self.class.types[type]
      # Otherwise it's a type error
      raise ArgumentError.new :type
    end
  end

  def to_db_value(name, value)
    val, type = normalize_input(name, value)
    validate_value(name, type, val)
    [val, type]
  end

  def type_hash(name)
    name = name.to_sym
    type = get_type(name)

    result = { type: type.to_s }

    if type == :enum
      if (klass = get_enum_class(name))
        result.merge!(valid_values: klass.values, translate_names: klass.translate_names?)
      else
        result.merge!(
          valid_values: @choices[name].map { |c| { name: c, value: c } },
          translate_names: false,
        )
      end
    end

    if type == :integer || type == :file_size_restriction
      result[:min] = @validators[name].dig(:opts, :min) if @validators[name].dig(
        :opts,
        :min,
      ).present?
      result[:max] = @validators[name].dig(:opts, :max) if @validators[name].dig(
        :opts,
        :max,
      ).present?
    end

    result[:allow_any] = @allow_any[name] if type == :list

    result[:choices] = @choices[name] if @choices.has_key? name
    result[:list_type] = @list_type[name] if @list_type.has_key? name
    result[:textarea] = @textareas[name] if @textareas.has_key? name
    if @json_schemas.has_key?(name) && json_klass = json_schema_class(name)
      result[:json_schema] = json_klass.schema
    end

    result
  end

  def get_enum_class(name)
    @enums[name]
  end

  def get_type(name)
    self.class.types[@types[name.to_sym]]
  end

  def get_list_type(name)
    @list_type[name.to_sym]
  end

  private

  def normalize_input(name, val)
    name = name.to_sym
    type = @types[name] || self.class.parse_value_type(val)

    if type == self.class.types[:bool]
      val = (val == true || val == "t" || val == "true") ? "t" : "f"
    elsif type == self.class.types[:integer] && !val.is_a?(Integer)
      val = val.to_i
    elsif type == self.class.types[:null] && val != ""
      type = get_data_type(name, val)
    elsif type == self.class.types[:enum]
      val =
        (
          if @defaults_provider[name].is_a?(Integer) && Integer(val, exception: false)
            val.to_i
          else
            val.to_s
          end
        )
    elsif type == self.class.types[:uploaded_image_list] && val.present?
      val = val.is_a?(String) ? val : val.map(&:id).join("|")
    elsif type == self.class.types[:upload] && val.present?
      val = val.is_a?(Integer) ? val : val.id
    end

    [val, type]
  end

  def validate_value(name, type, val)
    if type == self.class.types[:enum]
      if get_enum_class(name)
        unless get_enum_class(name).valid_value?(val)
          raise Discourse::InvalidParameters.new("Invalid value `#{val}` for `#{name}`")
        end
      else
        unless (choice = @choices[name])
          raise Discourse::InvalidParameters.new(name)
        end

        raise Discourse::InvalidParameters.new(:value) if choice.exclude?(val)
      end
    end

    if type == self.class.types[:list] || type == self.class.types[:string]
      if @allow_any.key?(name) && !@allow_any[name]
        split = val.to_s.split("|")
        resolved_choices = @choices[name]
        if resolved_choices.first.is_a?(Hash)
          resolved_choices = resolved_choices.map { |c| c[:value] }
        end
        diff = (split - resolved_choices)
        if diff.length > 0
          raise Discourse::InvalidParameters.new(
                  I18n.t(
                    "errors.site_settings.invalid_choice",
                    name: diff.join(","),
                    count: diff.length,
                  ),
                )
        end
      end
    end

    if (v = @validators[name])
      validator = v[:class].new(v[:opts])
      unless validator.valid_value?(val)
        raise Discourse::InvalidParameters, "#{name}: #{validator.error_message}"
      end
    end

    validate_method = "validate_#{name}"
    public_send(validate_method, val) if self.respond_to? validate_method
  end

  def get_data_type(name, val)
    # Some types are just for validations like email.
    # Only consider it valid if includes in `types`
    if (static_type = @static_types[name.to_sym])
      return self.class.types[static_type] if self.class.types.keys.include?(static_type)
    end

    self.class.parse_value_type(val)
  end

  def json_schema_class(name)
    @json_schemas[name]
  end

  def validator_for(type_name)
    case type_name
    when self.class.types[:email]
      EmailSettingValidator
    when self.class.types[:username]
      UsernameSettingValidator
    when self.class.types[:group]
      GroupSettingValidator
    when self.class.types[:integer]
      IntegerSettingValidator
    when self.class.types[:file_size_restriction]
      IntegerSettingValidator
    when self.class.types[:regex]
      RegexSettingValidator
    when self.class.types[:string], self.class.types[:list], self.class.types[:enum]
      StringSettingValidator
    when self.class.types[:host_list]
      HostListSettingValidator
    else
      nil
    end
  end
end
