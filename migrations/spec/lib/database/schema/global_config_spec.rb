# frozen_string_literal: true

RSpec.describe Migrations::Database::Schema::GlobalConfig do
  subject(:global_config) { described_class.new(schema_config) }

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
        tables: {
          exclude: %w[schema_migrations user_auth_tokens],
        },
      },
    }
  end

  describe "#excluded_column_names" do
    it "returns the globally excluded column names" do
      expect(global_config.excluded_column_names).to eq(%w[created_at updated_at])
    end
  end

  describe "#modified_columns" do
    it "returns the globally modified columns" do
      expect(global_config.modified_columns).to contain_exactly(
        { name: "username", datatype: :text },
        { name_regex: /_id$/, datatype: :bigint, name_regex_original: "_id$" },
      )
    end
  end

  describe "#excluded_table_name?" do
    it "returns true for globally excluded tables" do
      expect(global_config.excluded_table_name?("schema_migrations")).to be true
    end

    it "returns false for non-excluded tables" do
      expect(global_config.excluded_table_name?("users")).to be false
    end
  end

  describe "#modified_datatype" do
    it "returns the datatype for a modified column" do
      expect(global_config.modified_datatype("username")).to eq(:text)
    end

    it "returns the datatype for a column matching the regex" do
      expect(global_config.modified_datatype("user_id")).to eq(:bigint)
    end

    it "returns nil for non-modified columns" do
      expect(global_config.modified_datatype("non_existent_column")).to be_nil
    end
  end
end
