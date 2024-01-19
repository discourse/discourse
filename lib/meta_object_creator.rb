class MetaObjectCreator
  include HasErrors

  def initialize(schema_name)
    @schema = MetaSchema.find_by!(name: schema_name)
  end

  def create(attrs)
    MetaSchema.transaction do
      if valid?(attrs)
        # Do some creation
      end
    end
  end

  def valid?(attrs)
    @schema
      .columns
      .each do |column|
        if column.required? && attrs[column.name].blank?
          add_error(required_column, "and can't be blank") if attrs[required_column].blank?
        end

        if column.is_a?
      end
  end
end
