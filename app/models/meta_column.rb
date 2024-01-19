class MetaColumn < ActiveRecord::Base
  belongs_to :meta_schema
  belongs_to :detailable, polymorphic: true

  delegated_type :detailable, types: %w[StringMetaColumn IntegerMetaColumn EnumMetaColumn]

  def self.add_integer_field_to_schema(schema_id, field_name, required:, min_value:, max_value:)
    self.create!(
      meta_schema_id: schema_id,
      name: field_name,
      required:,
      detailable: IntegerMetaColumn.new(min_value:, max_value:),
    )
  end

  def self.add_string_field_to_schema(schema_id, field_name, required:, min_length:, max_length:)
    self.create!(
      meta_schema_id: schema_id,
      name: field_name,
      required:,
      detailable: StringMetaColumn.new(min_length:, max_length:),
    )
  end

  def self.add_enum_field_to_schema(schema_id, field_name, required:, values:)
    self.create!(
      meta_schema_id: schema_id,
      name: field_name,
      required:,
      detailable: EnumMetaColumn.new(values: values),
    )
  end
end
