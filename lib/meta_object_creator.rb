class MetaObjectCreator
  include HasErrors

  def initialize(schema_name)
    @schema = MetaSchema.find_by!(name: schema_name)
  end

  def create(attrs)
    attrs = attrs.with_indifferent_access
    ensure_valid_schema(attrs)
    return false if self.errors.present?

    meta_object =
      MetaObject.new(meta_schema: @schema, meta_fields: convert_attrs_to_meta_fields(attrs))

    if meta_object.valid?
      meta_object.save!
      true
    else
      self.add_errors_from(meta_object)
      false
    end
  end

  private

  def convert_attrs_to_meta_fields(attrs)
    @schema.meta_columns.map do |column|
      value = attrs[column.name]

      fieldable =
        case column.detailable_type
        when "StringMetaColumn"
          StringMetaField.new(value:)
        when "IntegerMetaColumn"
          IntegerMetaField.new(value:)
        when "EnumMetaColumn"
          EnumMetaField.new(value:)
        end

      MetaField.new(meta_column: column, fieldable: fieldable)
    end
  end

  def ensure_valid_schema(attrs)
    @schema.meta_columns.each do |column|
      self.add_error("#{column} can't be blank") if column.required? && attrs[column.name].blank?
    end
  end
end
