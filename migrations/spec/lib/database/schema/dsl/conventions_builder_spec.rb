# frozen_string_literal: true

RSpec.describe Migrations::Database::Schema::DSL::ConventionsBuilder do
  after { Migrations::Database::Schema.reset! }

  describe "Schema.conventions" do
    it "matches exact names before regex patterns" do
      Migrations::Database::Schema.conventions do
        column :id do
          rename_to :original_id
        end

        columns_matching(/^id/) { rename_to :other_name }
      end

      conventions = Migrations::Database::Schema.conventions_config
      expect(conventions.effective_name("id")).to eq("original_id")
    end

    it "tracks ignored columns" do
      Migrations::Database::Schema.conventions { ignore_columns :created_by, :updated_by }

      conventions = Migrations::Database::Schema.conventions_config
      expect(conventions.ignored_column?("created_by")).to be true
      expect(conventions.ignored_column?("updated_by")).to be true
      expect(conventions.ignored_column?("username")).to be false
    end
  end
end
