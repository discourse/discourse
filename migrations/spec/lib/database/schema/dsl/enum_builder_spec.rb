# frozen_string_literal: true

RSpec.describe Migrations::Database::Schema::DSL::EnumBuilder do
  after { Migrations::Database::Schema.reset! }

  describe "Schema.enum" do
    it "registers an enum with integer values" do
      Migrations::Database::Schema.enum :visibility do
        value :public, 0
        value :private, 1
        value :restricted, 2
      end

      enum = Migrations::Database::Schema.enums[:visibility]
      expect(enum.name).to eq(:visibility)
      expect(enum.values).to eq({ "public" => 0, "private" => 1, "restricted" => 2 })
      expect(enum.datatype).to eq(:integer)
    end

    it "registers an enum with string values" do
      Migrations::Database::Schema.enum :color do
        string_value :red, "red"
        string_value :blue, "blue"
      end

      enum = Migrations::Database::Schema.enums[:color]
      expect(enum.values).to eq({ "red" => "red", "blue" => "blue" })
      expect(enum.datatype).to eq(:text)
    end

    it "supports source evaluation" do
      Migrations::Database::Schema.enum :status do
        source "{ active: 0, inactive: 1 }"
      end

      enum = Migrations::Database::Schema.enums[:status]
      expect(enum.values).to eq({ "active" => 0, "inactive" => 1 })
      expect(enum.datatype).to eq(:integer)
    end

    it "supports source returning an Array" do
      Migrations::Database::Schema.enum :roles do
        source "[:admin, :moderator, :user]"
      end

      enum = Migrations::Database::Schema.enums[:roles]
      expect(enum.values).to eq({ "admin" => 0, "moderator" => 1, "user" => 2 })
    end

    it "raises when enum has no values" do
      expect do Migrations::Database::Schema.enum(:empty) {} end.to raise_error(
        Migrations::Database::Schema::ConfigError,
        /at least one value/,
      )
    end

    it "raises on invalid source" do
      expect do
        Migrations::Database::Schema.enum :bad do
          source "raise 'boom'"
        end
      end.to raise_error(Migrations::Database::Schema::ConfigError, /failed to evaluate/i)
    end

    it "raises on duplicate enum name" do
      Migrations::Database::Schema.enum(:status) { value :active, 0 }

      expect do
        Migrations::Database::Schema.enum(:status) { value :inactive, 1 }
      end.to raise_error(Migrations::Database::Schema::ConfigError, /already registered/)
    end

    it "raises when enum values mix strings and integers" do
      expect do
        Migrations::Database::Schema.enum :mixed do
          value :a, 0
          string_value :b, "b"
        end
      end.to raise_error(
        Migrations::Database::Schema::ConfigError,
        /all be Strings or all Integers/,
      )
    end

    it "raises when enum values are neither strings nor integers" do
      expect do
        Migrations::Database::Schema.enum :bad_values do
          value :a, true
        end
      end.to raise_error(
        Migrations::Database::Schema::ConfigError,
        /values must be Strings or Integers/,
      )
    end
  end
end
