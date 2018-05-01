require_dependency 'site_settings/validations'
require_dependency 'enum'

module SiteSettings; end

class SiteSettings::TypeSupervisor
  include SiteSettings::Validations

  CONSUMED_OPTS = %i[enum choices type validator min max regex hidden regex_error allow_any].freeze
  VALIDATOR_OPTS = %i[min max regex hidden regex_error].freeze

  # For plugins, so they can tell if a feature is supported
  SUPPORTED_TYPES = %i[email username list enum].freeze

  def self.types
    @types ||= Enum.new(
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
      category: 16
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
  end

  def load_setting(name_arg, opts = {})
    name = name_arg.to_sym

    if (enum = opts[:enum])
      @enums[name] = enum.is_a?(String) ? enum.constantize : enum
      opts[:type] ||= :enum
    end

    if (new_choices = opts[:choices])
      new_choices = eval(new_choices) if new_choices.is_a?(String)

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
      end
    end
    @types[name] = get_data_type(name, @defaults_provider[name])

    opts[:validator] = opts[:validator].try(:constantize)
    if (validator_type = (opts[:validator] || validator_for(@types[name])))
      @validators[name] = { class: validator_type, opts: opts.slice(*VALIDATOR_OPTS) }
    end
  end

  def to_rb_value(name, value, override_type = nil)
    name = name.to_sym
    type = @types[name] = (override_type || @types[name] || get_data_type(name, value))

    case type
    when self.class.types[:float]
      value.to_f
    when self.class.types[:integer]
      value.to_i
    when self.class.types[:bool]
      value == true || value == 't' || value == 'true'
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
    type = self.class.types[@types[name]]

    result = { type: type.to_s }

    if type == :enum
      if (klass = enum_class(name))
        result.merge!(valid_values: klass.values, translate_names: klass.translate_names?)
      else
        result.merge!(valid_values: @choices[name].map { |c| { name: c, value: c } }, translate_names: false)
      end
    end

    result[:choices] = @choices[name] if @choices.has_key? name
    result
  end

  private

  def normalize_input(name, val)
    name = name.to_sym
    type = @types[name] || self.class.parse_value_type(val)

    if type == self.class.types[:bool]
      val = (val == true || val == 't' || val == 'true') ? 't' : 'f'
    elsif type == self.class.types[:integer] && !val.is_a?(Integer)
      val = val.to_i
    elsif type == self.class.types[:null] && val != ''
      type = get_data_type(name, val)
    elsif type == self.class.types[:enum]
      val = @defaults_provider[name].is_a?(Integer) ? val.to_i : val.to_s
    end

    [val, type]
  end

  def validate_value(name, type, val)
    if type == self.class.types[:enum]
      if enum_class(name)
        raise Discourse::InvalidParameters.new(:value) unless enum_class(name).valid_value?(val)
      else
        raise Discourse::InvalidParameters.new(:value) unless @choices[name].include?(val)
      end
    end

    if type == self.class.types[:list] || type == self.class.types[:string]
      if @allow_any.key?(name) && !@allow_any[name]
        split = val.to_s.split("|")
        diff = (split - @choices[name])
        if diff.length > 0
          raise Discourse::InvalidParameters.new(I18n.t('errors.site_settings.invalid_choice', name: diff.join(','), count: diff.length))
        end
      end
    end

    if (v = @validators[name])
      validator = v[:class].new(v[:opts])
      unless validator.valid_value?(val)
        raise Discourse::InvalidParameters, "#{name.to_s}: #{validator.error_message}"
      end
    end

    validate_method = "validate_#{name}"
    if self.respond_to? validate_method
      send(validate_method, val)
    end
  end

  def get_data_type(name, val)
    # Some types are just for validations like email.
    # Only consider it valid if includes in `types`
    if (static_type = @static_types[name.to_sym])
      return self.class.types[static_type] if self.class.types.keys.include?(static_type)
    end

    self.class.parse_value_type(val)
  end

  def enum_class(name)
    @enums[name]
  end

  def validator_for(type_name)
    case type_name
    when self.class.types[:email]
      EmailSettingValidator
    when self.class.types[:username]
      UsernameSettingValidator
    when self.class.types[:integer]
      IntegerSettingValidator
    when self.class.types[:regex]
      RegexSettingValidator
    when self.class.types[:string], self.class.types[:list], self.class.types[:enum]
      StringSettingValidator
    else nil
    end
  end
end
