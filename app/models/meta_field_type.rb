class MetaFieldType < ActiveRecord::Base
  belongs_to :meta_schema

  has_one :string_meta_field_type, dependent: :destroy
  has_one :integer_meta_field_type, dependent: :destroy
  has_one :enum_meta_field_type, dependent: :destroy

  accepts_nested_attributes_for :integer_meta_field_type

  def self.add_integer_field_to_schema(schema_id, field_name, required:, min_value:, max_value:)
    self.create!(
      meta_schema_id: schema_id,
      name: field_name,
      type: "IntegerMetaFieldType",
      required:,
      integer_meta_field_type: IntegerMetaFieldType.new(min_value:, max_value:),
    )
  end

  def self.add_string_field_to_schema(schema_id, field_name, required:, min_length:, max_length:)
    self.create!(
      meta_schema_id: schema_id,
      name: field_name,
      type: "StringMetaFieldType",
      required:,
      string_meta_field_type: StringMetaFieldType.new(min_length:, max_length:),
    )
  end

  def self.add_enum_field_to_schema(schema_id, field_name, required:, values:)
    self.create!(
      meta_schema_id: schema_id,
      name: field_name,
      type: "EnumMetaFieldType",
      required:,
      enum_meta_field_type: EnumMetaFieldType.new(values: values),
    )
  end
end
