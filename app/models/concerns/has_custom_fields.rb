module HasCustomFields
  extend ActiveSupport::Concern
  module Helpers
    def self.append_field(target, key, value, types)
      if target.has_key?(key)
        target[key] = [target[key]] if !target[key].is_a? Array
        target[key] << cast_custom_field(key, value, types)
      else
        target[key] = cast_custom_field(key, value, types)
      end
    end

    CUSTOM_FIELD_TRUE = ['t','true', 'T', 'True', 'TRUE'].freeze unless defined? CUSTOM_FIELD_TRUE

    def self.cast_custom_field(key, value, types)
      return value unless types && type = types[key]

      case type
        when :boolean then !!CUSTOM_FIELD_TRUE.include?(value)
        when :integer then value.to_i
      else
        value
      end
    end
  end

  included do
    has_many :_custom_fields, dependent: :destroy, :class_name => "#{name}CustomField"
    after_save :save_custom_fields

    # To avoid n+1 queries, we have this function to retrieve lots of custom fields in one
    # go and create a "sideloaded" version for easy querying by id.
    def self.custom_fields_for_ids(ids, whitelisted_fields)
      klass = "#{name}CustomField".constantize
      foreign_key = "#{name.underscore}_id".to_sym

      result = {}

      return result if whitelisted_fields.blank?
      klass.where(foreign_key => ids, :name => whitelisted_fields).pluck(foreign_key, :name, :value).each do |cf|
        result[cf[0]] ||= {}
        append_custom_field(result[cf[0]], cf[1], cf[2])
      end
      result
    end

    def self.append_custom_field(target, key, value)
      HasCustomFields::Helpers.append_field(target,key,value,@custom_field_types)
    end


    def self.register_custom_field_type(name, type)
      @custom_field_types ||= {}
      @custom_field_types[name] = type
    end

  end

  def reload(options = nil)
    @custom_fields = nil
    @custom_fields_orig = nil
    super
  end


  def custom_fields
    @custom_fields ||= refresh_custom_fields_from_db.dup
  end

  def custom_fields=(data)
    custom_fields.replace(data)
  end

  def custom_fields_clean?
    # Check whether the cached version has been
    # changed on this model
    !@custom_fields || @custom_fields_orig == @custom_fields
  end

  protected

  def refresh_custom_fields_from_db
    target = Hash.new
    _custom_fields.pluck(:name,:value).each do |key, value|
      self.class.append_custom_field(target, key, value)
    end
    @custom_fields_orig = target
    @custom_fields = @custom_fields_orig.dup
  end

  def save_custom_fields
    if !custom_fields_clean?
      dup = @custom_fields.dup

      array_fields = {}

      _custom_fields.each do |f|
        if dup[f.name].is_a? Array
          # we need to collect Arrays fully before
          # we can compare them
          if !array_fields.has_key? f.name
            array_fields[f.name] = [f]
          else
            array_fields[f.name] << f
          end
        else
          if dup[f.name] != f.value
            f.destroy
          else
            dup.delete(f.name)
          end
        end
      end

      # let's iterate through our arrays and compare them
      array_fields.each do |field_name, fields|
        if fields.length == dup[field_name].length &&
            fields.map{|f| f.value} == dup[field_name]
          dup.delete(f.name)
        else
          fields.each{|f| f.destroy }
        end
      end

      dup.each do |k,v|
        if v.is_a? Array
          v.each {|subv| _custom_fields.create(name: k, value: subv)}
        else
          _custom_fields.create(name: k, value: v)
        end
      end

      refresh_custom_fields_from_db
    end
  end
end
