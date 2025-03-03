# frozen_string_literal: true

RSpec.describe ::Migrations::Database::Schema::Validation::GloballyConfiguredColumnsValidator do
  subject(:validator) { described_class.new(config, errors, db) }

  let(:errors) { [] }
  let(:config) { { schema: schema_config } }
  let(:schema_config) do
    {
      global: {
        columns: {
          exclude: %w[created_at updated_at],
          modify: [
            { name: "username", datatype: "text" },
            { name_regex: "_id$", datatype: "bigint" },
          ],
        },
      },
      tables: {
        users: {
          columns: {
            include: %w[id username created_at updated_at],
          },
        },
      },
    }
  end
  let(:db) { instance_double(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter) }
  let(:columns) do
    [
      instance_double(ActiveRecord::ConnectionAdapters::PostgreSQL::Column, name: "id"),
      instance_double(ActiveRecord::ConnectionAdapters::PostgreSQL::Column, name: "username"),
      instance_double(ActiveRecord::ConnectionAdapters::PostgreSQL::Column, name: "created_at"),
      instance_double(ActiveRecord::ConnectionAdapters::PostgreSQL::Column, name: "updated_at"),
      instance_double(ActiveRecord::ConnectionAdapters::PostgreSQL::Column, name: "user_id"),
    ]
  end

  before do
    allow(db).to receive(:tables).and_return(%w[users])
    allow(db).to receive(:columns).with("users").and_return(columns)
  end

  describe "#validate" do
    it "adds an error if globally excluded columns do not exist" do
      schema_config[:global][:columns][:exclude] = %w[foo bar]

      validator.validate
      expect(errors).to contain_exactly(
        I18n.t("schema.validator.global.excluded_columns_missing", column_names: "bar, foo"),
      )
    end

    it "adds an error if globally modified columns do not exist" do
      schema_config[:global][:columns][:modify] = [
        { name: "bar", datatype: "text" },
        { name: "foo", datatype: "text" },
      ]

      validator.validate
      expect(errors).to contain_exactly(
        I18n.t("schema.validator.global.modified_columns_missing", column_names: "bar, foo"),
      )
    end

    it "adds no error if all globally excluded columns exist" do
      validator.validate
      expect(errors).to be_empty
    end

    it "adds no error if all globally modified columns exist" do
      validator.validate
      expect(errors).to be_empty
    end

    it "adds no error if globally modified columns match regex" do
      schema_config[:global][:columns][:modify] = [{ name_regex: /_id$/, datatype: "bigint" }]

      validator.validate
      expect(errors).to be_empty
    end

    it "adds an error if no column matches regex of modified column" do
      schema_config[:global][:columns][:modify] = [{ name_regex: "_foo$", datatype: "bigint" }]

      validator.validate
      expect(errors).to contain_exactly(
        I18n.t("schema.validator.global.modified_columns_missing", column_names: "_foo$"),
      )
    end
  end
end
