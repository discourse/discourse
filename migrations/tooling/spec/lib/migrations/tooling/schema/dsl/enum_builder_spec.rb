# frozen_string_literal: true

RSpec.describe Migrations::Tooling::Schema::DSL::EnumBuilder do
  after { Migrations::Tooling::Schema.reset! }

  describe "Schema.enum" do
    it "registers an enum with integer values" do
      Migrations::Tooling::Schema.enum :visibility do
        value :public, 0
        value :private, 1
        value :restricted, 2
      end

      enum = Migrations::Tooling::Schema.enums["visibility"]
      expect(enum.name).to eq("visibility")
      expect(enum.values).to eq({ "public" => 0, "private" => 1, "restricted" => 2 })
      expect(enum.datatype).to eq(:integer)
    end

    it "registers an enum with string values" do
      Migrations::Tooling::Schema.enum :status do
        value :active, "active"
        value :archived, "archived"
      end

      enum = Migrations::Tooling::Schema.enums["status"]
      expect(enum.values).to eq({ "active" => "active", "archived" => "archived" })
      expect(enum.datatype).to eq(:text)
    end

    it "freezes the values of the built enum" do
      Migrations::Tooling::Schema.enum(:visibility) { value :public, 0 }

      expect(Migrations::Tooling::Schema.enums["visibility"].values).to be_frozen
    end

    it "raises when enum has no values" do
      expect do Migrations::Tooling::Schema.enum(:empty) {} end.to raise_error(
        Migrations::Tooling::Schema::ConfigError,
        /Enum :empty must define at least one value/,
      )
    end

    it "builds values from a source block returning a hash" do
      Migrations::Tooling::Schema.enum :colors do
        source { { red: 5, green: 9 } }
      end

      enum = Migrations::Tooling::Schema.enums["colors"]
      expect(enum.values).to eq({ "red" => 5, "green" => 9 })
      expect(enum.datatype).to eq(:integer)
    end

    it "builds values from a source block returning an array" do
      Migrations::Tooling::Schema.enum :levels do
        source { %i[low medium high] }
      end

      enum = Migrations::Tooling::Schema.enums["levels"]
      expect(enum.values).to eq({ "low" => 0, "medium" => 1, "high" => 2 })
      expect(enum.datatype).to eq(:integer)
    end

    it "raises when the source block returns neither a hash nor an array" do
      expect do
        Migrations::Tooling::Schema.enum :bad do
          source { 42 }
        end
      end.to raise_error(
        Migrations::Tooling::Schema::ConfigError,
        "Enum :bad source must return a Hash or Array, got Integer.",
      )
    end

    it "raises on invalid source" do
      expect do
        Migrations::Tooling::Schema.enum :bad do
          source { raise "boom" }
        end
      end.to raise_error(
        Migrations::Tooling::Schema::ConfigError,
        "Enum :bad failed to evaluate source: boom",
      )
    end

    it "raises on duplicate enum name" do
      Migrations::Tooling::Schema.enum(:status) { value :active, 0 }

      expect do Migrations::Tooling::Schema.enum(:status) { value :inactive, 1 } end.to raise_error(
        Migrations::Tooling::Schema::ConfigError,
        /already registered/,
      )
    end

    it "raises when enum values mix strings and integers" do
      expect do
        Migrations::Tooling::Schema.enum :mixed do
          value :a, 0
          value :b, "b"
        end
      end.to raise_error(
        Migrations::Tooling::Schema::ConfigError,
        /Enum :mixed values must all be Strings or all Integers/,
      )
    end

    it "raises when enum values are neither strings nor integers" do
      expect do
        Migrations::Tooling::Schema.enum :floats do
          value :a, 1.5
          value :b, 2.5
        end
      end.to raise_error(
        Migrations::Tooling::Schema::ConfigError,
        /Enum :floats values must be Strings or Integers, got Float/,
      )
    end
  end
end
