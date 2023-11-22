# frozen_string_literal: true

module HasCustomFields
  extend ActiveSupport::Concern

  module Helpers
    def self.append_field(target, key, value, types)
      if target.has_key?(key)
        target[key] = [target[key]] if !target[key].is_a? Array
        target[key] << cast_custom_field(key, value, types, _return_array = false)
      else
        target[key] = cast_custom_field(key, value, types)
      end
    end

    CUSTOM_FIELD_TRUE ||= %w[1 t true T True TRUE].freeze

    def self.get_custom_field_type(types, key)
      return unless types

      types[key]
    end

    def self.serialize(value, type)
      if value.is_a?(Hash) || type == :json
        value.to_json
      elsif TrueClass === value
        "t"
      elsif FalseClass === value
        "f"
      elsif Integer === value
        value.to_s
      else
        value
      end
    end

    def self.cast_custom_field(key, value, types, return_array = true)
      return value unless type = get_custom_field_type(types, key)

      array = nil

      if Array === type
        type = type[0]
        array = true if return_array
      end

      result =
        case type
        when :boolean
          !!CUSTOM_FIELD_TRUE.include?(value)
        when :integer
          value.to_i
        when :json
          parse_json_value(value, key)
        else
          value
        end

      array ? [result] : result
    end

    def self.parse_json_value(value, key)
      ::JSON.parse(value)
    rescue JSON::ParserError
      Rails.logger.warn(
        "Value '#{value}' for custom field '#{key}' is not json, it is being ignored.",
      )
      {}
    end
  end

  CUSTOM_FIELDS_MAX_ITEMS = 100
  CUSTOM_FIELDS_MAX_VALUE_LENGTH = 10_000_000

  module ClassMethods
    # To avoid n+1 queries, use this function to retrieve lots of custom fields in one go
    # and create a "sideloaded" version for easy querying by id.
    def custom_fields_for_ids(ids, allowed_fields)
      klass = "#{name}CustomField".constantize
      foreign_key = "#{name.underscore}_id".to_sym

      result = {}

      return result if allowed_fields.blank?

      klass
        .where(foreign_key => ids, :name => allowed_fields)
        .order(:id)
        .pluck(foreign_key, :name, :value)
        .each do |cf|
          result[cf[0]] ||= {}
          append_custom_field(result[cf[0]], cf[1], cf[2])
        end

      result
    end

    def append_custom_field(target, key, value)
      HasCustomFields::Helpers.append_field(target, key, value, @custom_field_types)
    end

    def register_custom_field_type(name, type)
      if Array === type
        Discourse.deprecate(
          "Array types for custom fields are deprecated, use type :json instead",
          drop_from: "3.3.0",
        )
      end

      @custom_field_types ||= {}
      @custom_field_types[name] = type
    end

    def get_custom_field_type(name)
      @custom_field_types ||= {}
      @custom_field_types[name] || :string
    end

    def preload_custom_fields(objects, fields)
      if objects.present?
        map = {}

        empty = {}
        fields.each { |field| empty[field] = nil }

        objects.each do |obj|
          map[obj.id] = obj
          obj.set_preloaded_custom_fields(empty.dup)
        end

        fk = (name.underscore << "_id")

        "#{name}CustomField"
          .constantize
          .order(:id)
          .where("#{fk} in (?)", map.keys)
          .where("name in (?)", fields)
          .pluck(fk, :name, :value)
          .each do |id, name, value|
            preloaded = map[id].preloaded_custom_fields

            preloaded.delete(name) if preloaded[name].nil?

            HasCustomFields::Helpers.append_field(preloaded, name, value, @custom_field_types)
          end
      end
    end
  end

  included do
    extend ClassMethods

    has_many :_custom_fields, dependent: :destroy, class_name: "#{name}CustomField"

    validate :custom_fields_max_items, unless: :custom_fields_clean?
    validate :custom_fields_value_length, unless: :custom_fields_clean?

    after_save :save_custom_fields
  end

  attr_reader :preloaded_custom_fields

  def custom_fields_fk
    @custom_fields_fk ||= "#{_custom_fields.reflect_on_all_associations(:belongs_to)[0].name}_id"
  end

  def reload(options = nil)
    clear_custom_fields
    super
  end

  def on_custom_fields_change
    # Callback when custom fields have changed
    # Override in model
  end

  def custom_fields_preloaded?
    !!@preloaded_custom_fields
  end

  def custom_field_preloaded?(name)
    @preloaded_custom_fields && @preloaded_custom_fields.key?(name)
  end

  def clear_custom_fields
    @custom_fields = nil
    @custom_fields_orig = nil
  end

  class NotPreloadedError < StandardError
  end
  class PreloadedProxy
    def initialize(preloaded, klass_with_custom_fields)
      @preloaded = preloaded
      @klass_with_custom_fields = klass_with_custom_fields
    end

    def [](key)
      if @preloaded.key?(key)
        @preloaded[key]
      else
        # for now you can not mix preload an non preload, it better just to fail
        raise NotPreloadedError,
              "Attempted to access the non preloaded custom field '#{key}' on the '#{@klass_with_custom_fields}' class. This is disallowed to prevent N+1 queries."
      end
    end
  end

  def set_preloaded_custom_fields(custom_fields)
    @preloaded_custom_fields = custom_fields

    # we have to clear this otherwise the fields are cached inside the
    # already existing proxy and no new ones are added, so when we check
    # for custom_fields[KEY] an error is likely to occur
    @preloaded_proxy = nil
  end

  def custom_fields
    if @preloaded_custom_fields
      return @preloaded_proxy ||= PreloadedProxy.new(@preloaded_custom_fields, self.class.to_s)
    end

    @custom_fields ||= refresh_custom_fields_from_db.dup
  end

  def custom_fields=(data)
    custom_fields.replace(data)
  end

  def custom_fields_clean?
    # Check whether the cached version has been changed on this model
    !@custom_fields || @custom_fields_orig == @custom_fields
  end

  # `upsert_custom_fields` will only insert/update existing fields, and will not
  # delete anything. It is safer under concurrency and is recommended when
  # you just want to attach fields to things without maintaining a specific
  # set of fields.
  def upsert_custom_fields(fields)
    fields.each do |k, v|
      row_count = _custom_fields.where(name: k).update_all(value: v)
      _custom_fields.create!(name: k, value: v) if row_count == 0

      custom_fields[k.to_s] = v # We normalize custom_fields as strings
    end

    on_custom_fields_change
  end

  def save_custom_fields(force = false)
    if force || !custom_fields_clean?
      ActiveRecord::Base.transaction do
        dup = @custom_fields.dup.with_indifferent_access
        fields_by_key = _custom_fields.reload.group_by(&:name)

        (dup.keys.to_set + fields_by_key.keys.to_set).each do |key|
          fields = fields_by_key[key] || []
          value = dup[key]
          field_type = self.class.get_custom_field_type(key)

          if Array === field_type || (field_type != :json && Array === value)
            value = value || []
            value.compact!
            sub_type = field_type[0]

            value.map! { |v| HasCustomFields::Helpers.serialize(v, sub_type) }

            unless value == fields.map(&:value)
              fields.each(&:destroy!)

              value.each { |subv| _custom_fields.create!(name: key, value: subv) }
            end
          else
            if value.nil?
              fields.each(&:destroy!)
            else
              value = HasCustomFields::Helpers.serialize(value, field_type)

              field = fields.find { |f| f.value == value }
              fields.select { |f| f != field }.each(&:destroy!)

              create_singular(key, value) if !field
            end
          end
        end
      end

      on_custom_fields_change
      refresh_custom_fields_from_db
    end
  end

  # We support unique indexes on certain fields. In the event two concurrent processes attempt to
  # update the same custom field we should catch the error and perform an update instead.
  def create_singular(name, value, field_type = nil)
    write_value = value.is_a?(Hash) || field_type == :json ? value.to_json : value
    write_value = "t" if write_value.is_a?(TrueClass)
    write_value = "f" if write_value.is_a?(FalseClass)
    row_count = DB.exec(<<~SQL, name: name, value: write_value, id: id, now: Time.zone.now)
      INSERT INTO #{_custom_fields.table_name} (#{custom_fields_fk}, name, value, created_at, updated_at)
      VALUES (:id, :name, :value, :now, :now)
      ON CONFLICT DO NOTHING
    SQL
    _custom_fields.where(name: name).update_all(value: write_value) if row_count == 0
  end

  protected

  def refresh_custom_fields_from_db
    target = HashWithIndifferentAccess.new
    _custom_fields
      .order(:id)
      .pluck(:name, :value)
      .each { |key, value| self.class.append_custom_field(target, key, value) }
    @custom_fields_orig = target
    @custom_fields = @custom_fields_orig.deep_dup
  end

  private

  def custom_fields_max_items
    if custom_fields.size > CUSTOM_FIELDS_MAX_ITEMS
      errors.add(
        :base,
        I18n.t("custom_fields.validations.max_items", max_items_number: CUSTOM_FIELDS_MAX_ITEMS),
      )
    end
  end

  def custom_fields_value_length
    return if custom_fields.values.all? { _1.to_s.size <= CUSTOM_FIELDS_MAX_VALUE_LENGTH }
    errors.add(
      :base,
      I18n.t(
        "custom_fields.validations.max_value_length",
        max_value_length: CUSTOM_FIELDS_MAX_VALUE_LENGTH,
      ),
    )
  end
end
