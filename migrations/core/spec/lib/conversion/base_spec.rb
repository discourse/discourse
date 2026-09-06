# frozen_string_literal: true

RSpec.describe Migrations::Conversion::Base do
  describe "#run" do
    let(:converter) do
      TemporaryConverterModule::Converter.new({ intermediate_db: { path: "intermediate.db" } })
    end

    before do
      Object.const_set(
        "TemporaryConverterModule",
        Module.new do
          const_set("Converter", Class.new(Migrations::Conversion::Base))
          const_set("Topics", Class.new(Migrations::Conversion::Step) { title "Converting topics" })
          const_set("Users", Class.new(Migrations::Conversion::Step) { title "Converting users" })
        end,
      )

      Migrations::Database::IntermediateDB.setup(nil)
      allow(converter).to receive(:create_database)
    end

    after do
      Migrations::Database::IntermediateDB.setup(nil)
      remove_test_const("TemporaryConverterModule")
    end

    it "builds one reporter, then runs the scheduler over the filtered steps" do
      scheduler = instance_double(Migrations::Conversion::StepScheduler, run: nil)
      scheduler_args = nil
      allow(Migrations::Conversion::StepScheduler).to receive(:new) do |**kwargs|
        scheduler_args = kwargs
        scheduler
      end

      reporter = nil
      allow(Migrations::Reporting::Factory).to receive(
        :build,
      ).and_wrap_original do |original, **kwargs|
        reporter = original.call(**kwargs)
        allow(reporter).to receive(:close).and_call_original
        reporter
      end

      converter.run(skip_steps: ["users"], max_parallel_steps: 3)

      expect(Migrations::Reporting::Factory).to have_received(:build).once
      expect(scheduler).to have_received(:run).once
      expect(reporter).to have_received(:close).once

      expect(scheduler_args[:step_classes]).to eq([TemporaryConverterModule::Topics])
      expect(scheduler_args[:max_parallel_steps]).to eq(3)
      expect(scheduler_args[:budget]).to be > 0
      expect(scheduler_args[:reporter]).to be(reporter)
      expect(scheduler_args[:step_factory]).to respond_to(:call)
    end
  end

  describe "#steps" do
    subject(:converter) { TemporaryConverterModule::Converter.new(nil) }

    # `filter_steps` is private; expose it through a subclass to assert the
    # exact order `--only`/`--skip` produce.
    let(:base) { Class.new(described_class) { public :filter_steps }.new(nil) }

    before do
      Object.const_set(
        "TemporaryConverterModule",
        Module.new do
          const_set("Converter", Class.new(Migrations::Conversion::Base))
          const_set("Categories", Class.new(Migrations::Conversion::Step))
          const_set("Topics", Class.new(Migrations::Conversion::Step))
          const_set("Users", Class.new(Migrations::Conversion::Step))
          const_set("SomeHelper", Class.new)
        end,
      )
    end

    after { remove_test_const("TemporaryConverterModule") }

    it "discovers `Step` subclasses" do
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
      filtered = base.filter_steps(converter.steps, ["categories"], [])

      expect(filtered).to eq(
        [TemporaryConverterModule::Users, TemporaryConverterModule::Categories],
      )
    end

    it "supports running a single step via `--only` even when its dependency is excluded" do
      TemporaryConverterModule::Categories.depends_on(:users)

      # `run` sorts the full step set first and filters afterwards, so
      # re-running a single step keeps working even when its dependency
      # isn't part of the filtered set.
      filtered = base.filter_steps(converter.steps, ["categories"], ["users"])

      expect(filtered).to eq([TemporaryConverterModule::Categories])
    end
  end
end
