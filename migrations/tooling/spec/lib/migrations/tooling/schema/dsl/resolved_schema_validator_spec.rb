# frozen_string_literal: true

RSpec.describe Migrations::Tooling::Schema::DSL::ResolvedSchemaValidator do
  def build_column(
    name: "col",
    datatype: :text,
    nullable: true,
    max_length: nil,
    is_primary_key: false,
    enum: nil
  )
    Migrations::Tooling::Schema::ColumnDefinition.new(
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
    Migrations::Tooling::Schema::TableDefinition.new(
      name:,
      columns:,
      indexes:,
      primary_key_column_names:,
      constraints:,
      model_mode:,
    )
  end

  def build_index(name: "idx_test", column_names: [], unique: false, condition: nil)
    Migrations::Tooling::Schema::IndexDefinition.new(name:, column_names:, unique:, condition:)
  end

  def build_constraint(name: "chk_test", type: :check, condition: "1=1")
    Migrations::Tooling::Schema::ConstraintDefinition.new(name:, type:, condition:)
  end

  def build_enum(name: "status", values: { "active" => 0 }, datatype: :integer)
    Migrations::Tooling::Schema::EnumDefinition.new(name:, values:, datatype:)
  end

  def build_schema(tables: [], enums: [])
    Migrations::Tooling::Schema::Definition.new(tables:, enums:)
  end

  describe "#validate" do
    it "returns no errors for a fully valid schema" do
      table =
        build_table(
          columns: [
            build_column(name: "id", datatype: :integer, is_primary_key: true, nullable: false),
          ],
          primary_key_column_names: ["id"],
          indexes: [build_index(name: "idx_valid", column_names: ["id"])],
          constraints: [build_constraint(name: "chk_valid", condition: "id > 0")],
        )
      schema =
        build_schema(
          tables: [table],
          enums: [
            build_enum(name: "status", values: { "active" => 0 }, datatype: :integer),
            build_enum(name: "labels", values: { "a" => "x" }, datatype: :text),
          ],
        )

      errors = described_class.new(schema).validate
      expect(errors).to be_empty
    end

    it "clears previously collected errors on each run" do
      table = build_table(columns: [build_column(name: "")])
      schema = build_schema(tables: [table])
      validator = described_class.new(schema)

      validator.validate
      expect(validator.validate).to eq(["Table 'test_table': column has empty name"])
    end

    it "detects invalid datatypes" do
      table = build_table(columns: [build_column(name: "col", datatype: :invalid_type)])
      schema = build_schema(tables: [table])

      errors = described_class.new(schema).validate
      expect(errors).to include(
        "Table 'test_table': column 'col' has invalid datatype 'invalid_type'",
      )
    end

    it "detects empty column names" do
      table = build_table(columns: [build_column(name: "")])
      schema = build_schema(tables: [table])

      errors = described_class.new(schema).validate
      expect(errors).to contain_exactly("Table 'test_table': column has empty name")
    end

    it "detects nullable primary key columns" do
      table =
        build_table(
          columns: [build_column(name: "id", is_primary_key: true, nullable: true)],
          primary_key_column_names: ["id"],
        )
      schema = build_schema(tables: [table])

      errors = described_class.new(schema).validate
      expect(errors).to include(
        "Table 'test_table': primary key column 'id' should not be nullable",
      )
    end

    it "detects duplicate column names" do
      table =
        build_table(
          columns: [
            build_column(name: "id"),
            build_column(name: "dup"),
            build_column(name: "dup"),
            build_column(name: "other"),
            build_column(name: "other"),
          ],
        )
      schema = build_schema(tables: [table])

      errors = described_class.new(schema).validate
      expect(errors).to contain_exactly("Table 'test_table': duplicate column names: dup, other")
    end

    it "detects primary key referencing missing columns" do
      table =
        build_table(
          columns: [build_column(name: "id")],
          primary_key_column_names: %w[id missing_one missing_two],
        )
      schema = build_schema(tables: [table])

      errors = described_class.new(schema).validate
      expect(errors).to contain_exactly(
        "Table 'test_table': primary key references missing columns: missing_one, missing_two",
      )
    end

    it "handles a nil primary key column list" do
      table = build_table(columns: [build_column(name: "id")], primary_key_column_names: nil)
      schema = build_schema(tables: [table])

      errors = described_class.new(schema).validate
      expect(errors).to be_empty
    end

    it "detects indexes referencing missing columns" do
      table =
        build_table(
          columns: [build_column(name: "id")],
          indexes: [
            build_index(name: "idx_missing", column_names: %w[nonexistent another_missing]),
          ],
        )
      schema = build_schema(tables: [table])

      errors = described_class.new(schema).validate
      expect(errors).to contain_exactly(
        "Table 'test_table': index 'idx_missing' references missing columns: nonexistent, another_missing",
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
      expect(errors).to contain_exactly("Table 'test_table': index has empty name")
    end

    it "detects duplicate index names" do
      table =
        build_table(
          columns: [build_column(name: "id")],
          indexes: [
            build_index(name: "idx_a", column_names: ["id"]),
            build_index(name: "idx_dup", column_names: ["id"]),
            build_index(name: "idx_dup", column_names: ["id"]),
            build_index(name: "idx_other", column_names: ["id"]),
            build_index(name: "idx_other", column_names: ["id"]),
          ],
        )
      schema = build_schema(tables: [table])

      errors = described_class.new(schema).validate
      expect(errors).to contain_exactly(
        "Table 'test_table': duplicate index names: idx_dup, idx_other",
      )
    end

    it "detects empty constraint names" do
      table =
        build_table(columns: [build_column(name: "id")], constraints: [build_constraint(name: "")])
      schema = build_schema(tables: [table])

      errors = described_class.new(schema).validate
      expect(errors).to contain_exactly("Table 'test_table': constraint has empty name")
    end

    it "detects empty constraint conditions" do
      table =
        build_table(
          columns: [build_column(name: "id")],
          constraints: [build_constraint(name: "chk_empty", condition: "")],
        )
      schema = build_schema(tables: [table])

      errors = described_class.new(schema).validate
      expect(errors).to contain_exactly(
        "Table 'test_table': constraint 'chk_empty' has empty condition",
      )
    end

    it "detects empty enum names" do
      enum = build_enum(name: "")
      schema = build_schema(enums: [enum])

      errors = described_class.new(schema).validate
      expect(errors).to contain_exactly("Enum has empty name")
    end

    it "detects enums with no values" do
      enum = build_enum(name: "status", values: {})
      schema = build_schema(enums: [enum])

      errors = described_class.new(schema).validate
      expect(errors).to contain_exactly("Enum 'status' has no values")
    end

    it "detects enums with invalid datatype" do
      enum = build_enum(name: "status", datatype: :float)
      schema = build_schema(enums: [enum])

      errors = described_class.new(schema).validate
      expect(errors).to include("Enum 'status' has invalid datatype 'float'")
    end

    it "detects enums with values that do not match datatype" do
      enum = build_enum(name: "status", values: { "active" => "active" }, datatype: :integer)
      schema = build_schema(enums: [enum])

      errors = described_class.new(schema).validate
      expect(errors).to contain_exactly(
        "Enum 'status' has values that do not match datatype 'integer'",
      )
    end

    it "accepts a valid text enum" do
      enum = build_enum(name: "labels", values: { "a" => "x" }, datatype: :text)
      schema = build_schema(enums: [enum])

      errors = described_class.new(schema).validate
      expect(errors).to be_empty
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
