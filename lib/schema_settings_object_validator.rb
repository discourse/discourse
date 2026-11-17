# frozen_string_literal: true

class SchemaSettingsObjectValidator
  class << self
    def validate_objects(schema:, objects:)
      valid_ids_lookup = valid_ids_lookup_for(schema:, objects:)

      objects.each_with_index.flat_map do |object, index|
        new(schema:, object:, valid_ids_lookup:).validate.flat_map do |pointer, errors|
          errors.humanize_messages("/#{index}#{pointer}")
        end
      end
    end

    def valid_ids_lookup_for(schema:, objects:)
      Hash.new do |lookup, type|
        column = TYPE_TO_MODEL_MAP[type][:column] || :id
        values = property_values_of_type(schema:, objects:, type:)
        values = values.grep(column == :name ? String : Integer)

        lookup[type] = TYPE_TO_MODEL_MAP[type][:klass].where(column => values).pluck(column).to_set
      end
    end

    def property_values_of_type(schema:, objects:, type:)
      values = Set.new

      objects.each do |object|
        values.merge(new(schema: schema, object: object).property_values_of_type(type))
      end

      values.to_a
    end

    def upload_ids(schema:, objects:)
      property_values_of_type(schema:, objects:, type: "upload").filter_map do |value|
        # TODO(gabriel): this if branch was to deal wit ha legacy logic bug where some upload fields were stored as URLs instead of IDs.
        # This can be removed by May 2027.
        if value.is_a?(Integer)
          value
        elsif value.is_a?(String) && value.present?
          Upload.get_from_url(value)&.id
        end
      end
    end

    def normalize_uploads(schema:, objects:)
      return objects if objects.blank?

      transform_uploads_in_objects(objects.deep_dup, schema[:properties]) do |value|
        if value.is_a?(String) && value.present?
          Upload.get_from_url(value)&.id || value
        else
          value
        end
      end
    end

    def hydrate_uploads(schema:, objects:, cdn: false)
      return objects if objects.blank?

      upload_ids = property_values_of_type(schema:, objects:, type: "upload").grep(Integer)
      return objects if upload_ids.empty?

      uploads_by_id = Upload.where(id: upload_ids).index_by(&:id)
      transform_uploads_in_objects(objects.deep_dup, schema[:properties]) do |value|
        if upload = uploads_by_id[value]
          cdn ? Discourse.store.cdn_url(upload.url) : upload.url
        else
          value
        end
      end
    end

    private

    def transform_uploads_in_objects(objects, properties, &block)
      objects.each do |object|
        properties.each do |property_name, property_attributes|
          key = object_key(object, property_name)
          next if key.nil?

          case property_attributes[:type]
          when "upload"
            object[key] = block.call(object[key])
          when "objects"
            nested_objects = object[key]
            if nested_objects.is_a?(Array)
              transform_uploads_in_objects(
                nested_objects,
                property_attributes[:schema][:properties],
                &block
              )
            end
          end
        end
      end

      objects
    end

    def object_key(object, property_name)
      string_key = property_name.to_s
      return string_key if object.key?(string_key)

      symbol_key = property_name.to_sym
      symbol_key if object.key?(symbol_key)
    end
  end

  class SchemaSettingsObjectErrors
    def initialize
      @errors = []
    end

    def add_error(error, i18n_opts = {})
      @errors << SchemaSettingsObjectError.new(error, i18n_opts)
    end

    def humanize_messages(property_json_pointer)
      @errors.map { |error| error.humanize_messages(property_json_pointer) }
    end

    def full_messages
      @errors.map(&:error_message)
    end
  end

  class SchemaSettingsObjectError
    def initialize(error, i18n_opts = {})
      @error = error
      @i18n_opts = i18n_opts
    end

    def humanize_messages(property_json_pointer)
      I18n.t(
        "themes.settings_errors.objects.humanize_#{@error}",
        @i18n_opts.merge(property_json_pointer:),
      )
    end

    def error_message
      I18n.t("themes.settings_errors.objects.#{@error}", @i18n_opts)
    end
  end

  def initialize(schema:, object:, json_pointer_prefix: "", errors: {}, valid_ids_lookup: nil)
    @object = object.with_indifferent_access
    @properties = schema[:properties]
    @errors = errors
    @json_pointer_prefix = json_pointer_prefix
    @valid_ids_lookup =
      valid_ids_lookup || self.class.valid_ids_lookup_for(schema:, objects: [object])
  end

  def validate
    @properties.each do |property_name, property_attributes|
      if property_attributes[:type] == "objects"
        validate_child_objects(
          @object[property_name],
          property_name:,
          schema: property_attributes[:schema],
        )
      else
        validate_property(property_name, property_attributes)
      end
    end

    @errors
  end

  def property_values_of_type(type)
    fetch_property_values_of_type(@properties, @object, type)
  end

  private

  def validate_child_objects(objects, property_name:, schema:)
    return if objects.blank?

    objects.each_with_index do |object, index|
      self
        .class
        .new(
          schema:,
          object:,
          valid_ids_lookup: @valid_ids_lookup,
          json_pointer_prefix: "#{@json_pointer_prefix}#{property_name}/#{index}/",
          errors: @errors,
        )
        .validate
    end
  end

  def validate_property(property_name, property_attributes)
    return if !has_valid_property_value_type?(property_attributes, property_name)

    if absent?(@object[property_name])
      add_error(property_name, :required) if property_attributes[:required]
      return
    end

    has_valid_property_value?(property_attributes, property_name)
  end

  def absent?(value)
    value != false && value.blank?
  end

  def has_valid_property_value_type?(property_attributes, property_name)
    value = @object[property_name]
    type = property_attributes[:type]

    return true if value.nil?

    is_value_valid =
      case type
      when "string", "datetime", "icon"
        value.is_a?(String)
      when "integer", "topic", "post"
        value.is_a?(Integer)
      when "upload"
        if value.is_a?(String)
          if upload = Upload.get_from_url(value)
            @object[property_name] = upload.id
            # upload already verified via get_from_url, so we can add it to valid ids
            @valid_ids_lookup["upload"] << upload.id
            true
          else
            false
          end
        else
          value.is_a?(Integer)
        end
      when "float"
        value.is_a?(Float) || value.is_a?(Integer)
      when "boolean"
        [true, false].include?(value)
      when "enum"
        property_attributes[:choices].include?(value)
      when "categories", "groups"
        value.is_a?(Array) && value.all? { |id| id.is_a?(Integer) }
      when "tags"
        value.is_a?(Array) && value.all? { |tag| tag.is_a?(String) }
      else
        add_error(property_name, :invalid_type, type:)
        return false
      end

    if is_value_valid
      true
    else
      add_error(property_name, "not_valid_#{type}_value", property_attributes)
      false
    end
  end

  def has_valid_property_value?(property_attributes, property_name)
    validations = property_attributes[:validations]
    type = property_attributes[:type]
    value = @object[property_name]

    case type
    when "topic", "upload", "post"
      if !@valid_ids_lookup[type].include?(value)
        add_error(property_name, :"not_valid_#{type}_value")
        return false
      end
    when "tags", "categories", "groups"
      if !value.to_set.subset?(@valid_ids_lookup[type])
        add_error(property_name, :"not_valid_#{type}_value")
        return false
      end

      if (min = validations&.dig(:min)) && value.length < min
        add_error(property_name, :"#{type}_value_not_valid_min", count: min)
        return false
      end

      if (max = validations&.dig(:max)) && value.length > max
        add_error(property_name, :"#{type}_value_not_valid_max", count: max)
        return false
      end
    when "datetime"
      if !DatetimeSettingValidator.new.valid_value?(value)
        add_error(property_name, :not_valid_datetime_value)
        return false
      end
    when "string"
      if (min = validations&.dig(:min_length)) && value.length < min
        add_error(property_name, :string_value_not_valid_min, count: min)
        return false
      end

      if (max = validations&.dig(:max_length)) && value.length > max
        add_error(property_name, :string_value_not_valid_max, count: max)
        return false
      end

      if validations&.dig(:url) && !UrlHelper.is_valid_url?(value)
        add_error(property_name, :string_value_not_valid_url)
        return false
      end
    when "integer", "float"
      if (min = validations&.dig(:min)) && value < min
        add_error(property_name, :number_value_not_valid_min, min:)
        return false
      end

      if (max = validations&.dig(:max)) && value > max
        add_error(property_name, :number_value_not_valid_max, max:)
        return false
      end
    end

    true
  end

  def add_error(property_name, key, i18n_opts = {})
    pointer = json_pointer(property_name)
    @errors[pointer] ||= SchemaSettingsObjectErrors.new
    @errors[pointer].add_error(key, i18n_opts)
  end

  def json_pointer(property_name)
    "/#{@json_pointer_prefix}#{property_name}"
  end

  TYPE_TO_MODEL_MAP = {
    "categories" => {
      klass: Category,
    },
    "topic" => {
      klass: Topic,
    },
    "post" => {
      klass: Post,
    },
    "groups" => {
      klass: Group,
    },
    "upload" => {
      klass: Upload,
    },
    "tags" => {
      klass: Tag,
      column: :name,
    },
  }
  private_constant :TYPE_TO_MODEL_MAP

  def fetch_property_values_of_type(properties, object, type)
    values = Set.new

    properties.each do |property_name, property_attributes|
      if property_attributes[:type] == type
        values.merge(Array(object[property_name]))
      elsif property_attributes[:type] == "objects"
        object[property_name]&.each do |child_object|
          values.merge(
            fetch_property_values_of_type(
              property_attributes[:schema][:properties],
              child_object,
              type,
            ),
          )
        end
      end
    end

    values
  end
end
