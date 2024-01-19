class MetaSchemaCreator
  # @returns [MetaSchema] the created schema
  def self.create(schema_name, columns)
    schema =
      MetaSchema.new(
        name: schema_name,
        meta_columns:
          columns.map do |column|
            MetaColumn.new(
              name: column[:name],
              required: ActiveModel::Type::Boolean.new.cast(column[:required]),
              detailable:
                case column[:type].to_s
                when "string"
                  StringMetaColumn.new(
                    min_length: column.dig(:validations, :min_length),
                    max_length: column.dig(:validations, :max_length),
                  )
                when "integer"
                  IntegerMetaColumn.new(
                    min_value: column.dig(:validations, :min_value),
                    max_value: column.dig(:validations, :max_value),
                  )
                when "enum"
                  EnumMetaColumn.new(values: column[:choices])
                end,
            )
          end,
      )

    if schema.save
      schema
    else
      raise schema.errors.full_messages.join(", ")
    end
  end
end
