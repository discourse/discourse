# frozen_string_literal: true

RSpec.describe Migrations::Database::Schema::DSL::ConventionsBuilder do
  after { Migrations::Database::Schema.reset! }

  describe "Schema.conventions" do
    it "registers column conventions with exact match" do
      Migrations::Database::Schema.conventions do
        column :id do
          rename_to :original_id
          type :integer
          required
        end
      end

      conventions = Migrations::Database::Schema.conventions_config
      expect(conventions).to be_a(Migrations::Database::Schema::DSL::ConventionsConfig)

      convention = conventions.convention_for("id")
      expect(convention.rename_to).to eq(:original_id)
      expect(convention.type_override).to eq(:integer)
      expect(convention.required).to eq(true)
    end

    it "matches exact names before regex patterns" do
      Migrations::Database::Schema.conventions do
        column :id do
          rename_to :original_id
        end

        columns_matching(/^id/) { rename_to :other_name }
      end

      conventions = Migrations::Database::Schema.conventions_config
      expect(conventions.effective_name("id")).to eq(:original_id)
    end

    it "matches regex patterns" do
      Migrations::Database::Schema.conventions { columns_matching(/_at$/) { type :datetime } }

      conventions = Migrations::Database::Schema.conventions_config
      convention = conventions.convention_for("created_at")
      expect(convention.type_override).to eq(:datetime)
    end

    it "returns original name when no convention matches" do
      Migrations::Database::Schema.conventions do
        column :id do
          rename_to :original_id
        end
      end

      conventions = Migrations::Database::Schema.conventions_config
      expect(conventions.effective_name("username")).to eq(:username)
    end

    it "tracks ignored columns" do
      Migrations::Database::Schema.conventions { ignore_columns :created_by, :updated_by }

      conventions = Migrations::Database::Schema.conventions_config
      expect(conventions.ignored_column?("created_by")).to be true
      expect(conventions.ignored_column?("updated_by")).to be true
      expect(conventions.ignored_column?("username")).to be false
    end

    it "checks required? via convention" do
      Migrations::Database::Schema.conventions do
        column :id do
          required
        end
      end

      conventions = Migrations::Database::Schema.conventions_config
      expect(conventions.required?("id")).to be true
      expect(conventions.required?("username")).to be false
    end
  end
end
