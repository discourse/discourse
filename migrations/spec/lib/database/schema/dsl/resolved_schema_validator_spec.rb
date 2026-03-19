# frozen_string_literal: true

RSpec.describe Migrations::Database::Schema::DSL::ResolvedSchemaValidator do
  def build_column(
    name: "col",
    datatype: :text,
    nullable: true,
    max_length: nil,
    is_primary_key: false,
    enum: nil
  )
    Migrations::Database::Schema::ColumnDefinition.new(
      name:,
      datatype:,
      nullable:,
      max_length:,
      is_primary_key:,
      enum:,
    )
  end

  def build_table(
    name: "test_table",
    columns: [],
    indexes: [],
    primary_key_column_names: [],
    constraints: [],
    model_mode: nil
  )
    Migrations::Database::Schema::TableDefinition.new(
      name:,
      columns:,
      indexes:,
      primary_key_column_names:,
      constraints:,
      model_mode:,
    )
  end

  def build_index(name: "idx_test", column_names: [], unique: false, condition: nil)
    Migrations::Database::Schema::IndexDefinition.new(name:, column_names:, unique:, condition:)
  end

  def build_constraint(name: "chk_test", type: :check, condition: "1=1")
    Migrations::Database::Schema::ConstraintDefinition.new(name:, type:, condition:)
  end

  def build_enum(name: "status", values: { "active" => 0 }, datatype: :integer)
    Migrations::Database::Schema::EnumDefinition.new(name:, values:, datatype:)
  end

  def build_schema(tables: [], enums: [])
    Migrations::Database::Schema::Definition.new(tables:, enums:)
  end

  describe "#validate" do
    it "returns no errors for a valid schema" do
      table =
        build_table(
          columns: [
            build_column(name: "id", datatype: :integer, is_primary_key: true, nullable: false),
          ],
          primary_key_column_names: ["id"],
        )
      schema = build_schema(tables: [table])

      errors = described_class.new(schema).validate
      expect(errors).to be_empty
    end

    it "detects invalid datatypes" do
      table = build_table(columns: [build_column(datatype: :invalid_type)])
      schema = build_schema(tables: [table])

      errors = described_class.new(schema).validate
      expect(errors).to include(match(/invalid datatype 'invalid_type'/))
    end

    it "detects empty column names" do
      table = build_table(columns: [build_column(name: "")])
      schema = build_schema(tables: [table])

      errors = described_class.new(schema).validate
      expect(errors).to include(match(/column has empty name/))
    end

    it "detects nullable primary key columns" do
      table =
        build_table(
          columns: [build_column(name: "id", is_primary_key: true, nullable: true)],
          primary_key_column_names: ["id"],
        )
      schema = build_schema(tables: [table])

      errors = described_class.new(schema).validate
      expect(errors).to include(match(/primary key column 'id' should not be nullable/))
    end

    it "detects duplicate column names" do
      table = build_table(columns: [build_column(name: "dup"), build_column(name: "dup")])
      schema = build_schema(tables: [table])

      errors = described_class.new(schema).validate
      expect(errors).to include(match(/duplicate column names: dup/))
    end

    it "detects primary key referencing missing columns" do
      table =
        build_table(
          columns: [build_column(name: "id")],
          primary_key_column_names: %w[id missing_col],
        )
      schema = build_schema(tables: [table])

      errors = described_class.new(schema).validate
      expect(errors).to include(match(/primary key references missing columns: missing_col/))
    end

    it "detects indexes referencing missing columns" do
      table =
        build_table(
          columns: [build_column(name: "id")],
          indexes: [build_index(name: "idx_missing", column_names: ["nonexistent"])],
        )
      schema = build_schema(tables: [table])

      errors = described_class.new(schema).validate
      expect(errors).to include(
        match(/index 'idx_missing' references missing columns: nonexistent/),
      )
    end

    it "detects empty index names" do
      table =
        build_table(
          columns: [build_column(name: "id")],
          indexes: [build_index(name: "", column_names: ["id"])],
        )
      schema = build_schema(tables: [table])

      errors = described_class.new(schema).validate
      expect(errors).to include(match(/index has empty name/))
    end

    it "detects duplicate index names" do
      table =
        build_table(
          columns: [build_column(name: "id")],
          indexes: [
            build_index(name: "idx_dup", column_names: ["id"]),
            build_index(name: "idx_dup", column_names: ["id"]),
          ],
        )
      schema = build_schema(tables: [table])

      errors = described_class.new(schema).validate
      expect(errors).to include(match(/duplicate index names: idx_dup/))
    end

    it "detects empty constraint names" do
      table =
        build_table(columns: [build_column(name: "id")], constraints: [build_constraint(name: "")])
      schema = build_schema(tables: [table])

      errors = described_class.new(schema).validate
      expect(errors).to include(match(/constraint has empty name/))
    end

    it "detects empty constraint conditions" do
      table =
        build_table(
          columns: [build_column(name: "id")],
          constraints: [build_constraint(name: "chk_empty", condition: "")],
        )
      schema = build_schema(tables: [table])

      errors = described_class.new(schema).validate
      expect(errors).to include(match(/constraint 'chk_empty' has empty condition/))
    end

    it "detects empty enum names" do
      enum = build_enum(name: "")
      schema = build_schema(enums: [enum])

      errors = described_class.new(schema).validate
      expect(errors).to include(match(/Enum has empty name/))
    end

    it "detects enums with no values" do
      enum = build_enum(values: {})
      schema = build_schema(enums: [enum])

      errors = described_class.new(schema).validate
      expect(errors).to include(match(/has no values/))
    end

    it "detects enums with invalid datatype" do
      enum = build_enum(datatype: :float)
      schema = build_schema(enums: [enum])

      errors = described_class.new(schema).validate
      expect(errors).to include(match(/invalid datatype 'float'/))
    end

    it "detects enums with values that do not match datatype" do
      enum = build_enum(values: { "active" => "active" }, datatype: :integer)
      schema = build_schema(enums: [enum])

      errors = described_class.new(schema).validate
      expect(errors).to include(match(/do not match datatype 'integer'/))
    end

    it "accepts all valid datatypes" do
      valid_types = %i[blob boolean date datetime float inet integer json numeric text]
      columns = valid_types.map { |t| build_column(name: "col_#{t}", datatype: t) }
      table = build_table(columns:)
      schema = build_schema(tables: [table])

      errors = described_class.new(schema).validate
      expect(errors).to be_empty
    end
  end
end
