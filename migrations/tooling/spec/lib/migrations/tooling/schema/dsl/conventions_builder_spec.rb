# frozen_string_literal: true

RSpec.describe Migrations::Tooling::Schema::DSL::ConventionsBuilder do
  after { Migrations::Tooling::Schema.reset! }

  describe "Schema.conventions" do
    it "matches exact names before regex patterns" do
      Migrations::Tooling::Schema.conventions do
        column :id do
          rename_to :original_id
        end

        columns_matching(/^id/) { rename_to :other_name }
      end

      conventions = Migrations::Tooling::Schema.conventions_config
      expect(conventions.effective_name("id")).to eq("original_id")
    end

    it "applies a regex pattern to columns matched only by the pattern" do
      Migrations::Tooling::Schema.conventions { columns_matching(/^post/) { rename_to :renamed } }

      conventions = Migrations::Tooling::Schema.conventions_config
      expect(conventions.effective_name("post_number")).to eq("renamed")
      expect(conventions.effective_name("topic_id")).to eq("topic_id")
    end

    it "converts a string pattern into a regex before matching" do
      Migrations::Tooling::Schema.conventions { columns_matching("_at$") { rename_to :timestamp } }

      conventions = Migrations::Tooling::Schema.conventions_config
      expect(conventions.effective_name("created_at")).to eq("timestamp")
      expect(conventions.effective_name("name")).to eq("name")
    end

    it "tracks ignored columns" do
      Migrations::Tooling::Schema.conventions { ignore_columns :created_by, :updated_by }

      conventions = Migrations::Tooling::Schema.conventions_config
      expect(conventions.ignored_column?("created_by")).to be true
      expect(conventions.ignored_column?("updated_by")).to be true
      expect(conventions.ignored_column?("username")).to be false
    end

    it "flattens nested arrays passed to ignore_columns" do
      Migrations::Tooling::Schema.conventions { ignore_columns %i[created_by updated_by] }

      conventions = Migrations::Tooling::Schema.conventions_config
      expect(conventions.ignored_column?("created_by")).to be true
      expect(conventions.ignored_column?("updated_by")).to be true
    end

    it "freezes the collections it builds" do
      Migrations::Tooling::Schema.conventions do
        column(:id) { rename_to :original_id }
        ignore_columns :created_by
      end

      conventions = Migrations::Tooling::Schema.conventions_config
      expect(conventions.conventions).to be_frozen
      expect(conventions.ignored_columns).to be_frozen
    end
  end
end
