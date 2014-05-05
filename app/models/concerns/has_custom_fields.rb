
module HasCustomFields
  extend ActiveSupport::Concern

  included do
    has_many :_custom_fields, dependent: :destroy, :class_name => "#{name}CustomField"
    after_save :save_custom_fields
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
      if target.has_key? key
        if !target[key].is_a? Array
          target[key] = [target[key]]
        end
        target[key] << value
      else
        target[key] = value
      end
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