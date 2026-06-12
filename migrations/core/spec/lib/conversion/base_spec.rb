# frozen_string_literal: true

RSpec.describe Migrations::Conversion::Base do
  describe "#steps" do
    subject(:converter) { TemporaryConverterModule::Converter.new(nil) }

    before do
      Object.const_set(
        "TemporaryConverterModule",
        Module.new do
          const_set("Converter", Class.new(Migrations::Conversion::Base))
          const_set("Categories", Class.new(Migrations::Conversion::Step))
          const_set("Topics", Class.new(Migrations::Conversion::ProgressStep))
          const_set("Users", Class.new(Migrations::Conversion::Step))
          const_set("SomeHelper", Class.new)
        end,
      )
    end

    after { Object.send(:remove_const, "TemporaryConverterModule") }

    it "discovers both `Step` and `ProgressStep` subclasses" do
      expect(converter.steps).to contain_exactly(
        TemporaryConverterModule::Categories,
        TemporaryConverterModule::Topics,
        TemporaryConverterModule::Users,
      )
    end

    it "returns steps in alphabetical order when no dependencies are declared" do
      # Regression for the switch from `sort_by(&:to_s)` to `TopologicalSorter`:
      # without dependencies and priorities, the order must stay exactly the
      # alphabetical order the previous implementation produced.
      expect(converter.steps).to eq(
        [
          TemporaryConverterModule::Categories,
          TemporaryConverterModule::Topics,
          TemporaryConverterModule::Users,
        ],
      )
    end

    it "orders steps after their dependencies regardless of alphabetical order" do
      TemporaryConverterModule::Categories.depends_on(:users)

      expect(converter.steps).to eq(
        [
          TemporaryConverterModule::Topics,
          TemporaryConverterModule::Users,
          TemporaryConverterModule::Categories,
        ],
      )
    end

    it "raises an error for circular dependencies" do
      TemporaryConverterModule::Categories.depends_on(:users)
      TemporaryConverterModule::Users.depends_on(:categories)

      expect { converter.steps }.to raise_error(
        Migrations::TopologicalSorterError,
        "Circular dependency detected",
      )
    end

    it "keeps pulled-in dependencies ordered before the steps that depend on them" do
      TemporaryConverterModule::Categories.depends_on(:users)

      # `--only categories` pulls in the `users` dependency; it has to run
      # before `categories` because the filtered list is executed as-is.
      filtered = converter.send(:filter_steps, converter.steps, ["categories"], [])

      expect(filtered).to eq(
        [TemporaryConverterModule::Users, TemporaryConverterModule::Categories],
      )
    end

    it "supports running a single step via `--only` even when its dependency is excluded" do
      TemporaryConverterModule::Categories.depends_on(:users)

      # `run` sorts the full step set first and filters afterwards, so
      # re-running a single step keeps working even when its dependency
      # isn't part of the filtered set.
      filtered = converter.send(:filter_steps, converter.steps, ["categories"], ["users"])

      expect(filtered).to eq([TemporaryConverterModule::Categories])
    end
  end
end
