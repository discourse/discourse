class MetaSchemaCreator
  # @returns [MetaSchema] the created schema
  def self.create!(schema_name, columns, theme_id: nil)
    MetaSchema.create!(
      name: schema_name,
      theme_id:,
      meta_columns:
        columns.map do |column|
          attrs = {
            name: column[:name],
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
          }

          if !(required = ActiveModel::Type::Boolean.new.cast(column[:required])).nil?
            attrs[:required] = required
          end

          MetaColumn.new(attrs)
        end,
    )
  end
end
