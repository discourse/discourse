# frozen_string_literal: true

RSpec.describe Migrations::Conversion::Base do
  describe "#initialize" do
    it "stores the settings" do
      settings = { intermediate_db: { path: "intermediate.db" } }
      expect(described_class.new(settings).settings).to be(settings)
    end
  end

  describe "#step_args" do
    it "returns an empty hash by default" do
      converter = described_class.new(nil)
      expect(converter.step_args(Migrations::Conversion::Step)).to eq({})
    end
  end

  describe "#run" do
    let(:settings) { { intermediate_db: { path: "intermediate.db" } } }
    let(:converter) { TemporaryConverterModule::Converter.new(settings) }

    let(:scheduler) { instance_double(Migrations::Conversion::StepScheduler, run: nil) }
    let(:shard_manager) { instance_double(Migrations::Conversion::ShardManager, cleanup: nil) }
    let(:writer) { instance_double(Migrations::Database::Connection) }

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
    end

    after do
      Migrations::Database::IntermediateDB.setup(nil)
      Object.send(:remove_const, "TemporaryConverterModule")
    end

    # Captures the keyword arguments the scheduler is built with, and stubs its
    # `run` so nothing is actually forked.
    def stub_scheduler
      args = nil
      allow(Migrations::Conversion::StepScheduler).to receive(:new) do |**kwargs|
        args = kwargs
        scheduler
      end
      -> { args }
    end

    # Captures the reporter the factory returns so we can assert it is reused and
    # closed, while keeping the real (plain) reporter.
    def stub_reporter
      reporter = nil
      allow(Migrations::Reporting::Factory).to receive(:build).and_wrap_original do |original, **kwargs|
        reporter = original.call(**kwargs)
        allow(reporter).to receive(:close).and_call_original
        reporter
      end
      -> { reporter }
    end

    it "builds one reporter, then runs the scheduler over the filtered steps" do
      allow(converter).to receive(:create_database) do
        converter.instance_variable_set(:@shard_manager, shard_manager)
        converter.instance_variable_set(:@writer, writer)
      end
      allow(Migrations::Database::IntermediateDB).to receive(:close).and_call_original
      allow(STDERR).to receive(:puts)

      scheduler_args = stub_scheduler
      reporter = stub_reporter

      converter.run(skip_steps: ["users"], max_parallel_steps: 3)

      # A clean run must not print the abort line (which is guarded by `@aborted`).
      expect(STDERR).not_to have_received(:puts)
      expect(converter).to have_received(:create_database).once
      expect(Migrations::Reporting::Factory).to have_received(:build).with(
        titles: ["Converting topics"],
      ).once
      expect(scheduler).to have_received(:run).once
      expect(reporter.call).to have_received(:close).once
      expect(Migrations::Database::IntermediateDB).to have_received(:close)
      expect(shard_manager).to have_received(:cleanup).once

      args = scheduler_args.call
      expect(args[:step_classes]).to eq([TemporaryConverterModule::Topics])
      expect(args[:max_parallel_steps]).to eq(3)
      expect(args[:no_fork]).to be(false)
      expect(args[:budget]).to be > 0
      expect(args[:reporter]).to be(reporter.call)
      expect(args[:shard_manager]).to be(shard_manager)
      expect(args[:writer]).to be(writer)
      expect(args[:step_factory]).to respond_to(:call)
    end

    it "uses empty filters and forking by default" do
      allow(converter).to receive(:create_database)
      scheduler_args = stub_scheduler

      # No `only_steps`/`skip_steps`/`max_parallel_steps` given: they must fall
      # back to their defaults instead of being required or `nil`.
      converter.run

      args = scheduler_args.call
      expect(args[:step_classes]).to eq(
        [TemporaryConverterModule::Topics, TemporaryConverterModule::Users],
      )
      expect(args[:max_parallel_steps]).to be_nil
      expect(args[:no_fork]).to be(false)
      expect(scheduler).to have_received(:run).once
    end

    it "runs the optional setup hook before creating the database" do
      allow(converter).to receive(:create_database)
      stub_scheduler

      steps = []
      converter.define_singleton_method(:setup) { steps << :setup }
      allow(converter).to receive(:create_database) { steps << :create_database }
      expect(converter).to receive(:puts).with("Initializing...") { steps << :puts }

      converter.run

      expect(steps).to eq(%i[puts setup create_database])
    end

    it "does not announce setup when the converter has no setup hook" do
      allow(converter).to receive(:create_database)
      stub_scheduler
      allow(converter).to receive(:puts)

      converter.run

      expect(converter).not_to have_received(:puts)
    end

    it "aborts with exit code 130 when a step raises a signal" do
      allow(converter).to receive(:create_database)
      allow(Migrations::Conversion::StepScheduler).to receive(:new).and_return(scheduler)
      allow(scheduler).to receive(:run).and_raise(SignalException.new("INT"))
      allow(STDERR).to receive(:puts)

      expect { converter.run }.to raise_error(SystemExit) { |error| expect(error.status).to eq(130) }

      expect(STDERR).to have_received(:puts).with("\n#{I18n.t("cli.aborted")}")
    end

    it "closes intermediate resources even when set up never finished" do
      allow(converter).to receive(:create_database).and_raise("boom")
      allow(Migrations::Database::IntermediateDB).to receive(:close).and_call_original

      # `@reporter` and `@shard_manager` are still nil here, so the ensure block
      # has to guard both before closing/cleaning them up.
      expect { converter.run }.to raise_error("boom")
      expect(Migrations::Database::IntermediateDB).to have_received(:close)
    end
  end

  describe "#create_database" do
    let(:settings) { { intermediate_db: { path: "sub/intermediate.db" } } }
    let(:converter) { described_class.new(settings) }
    let(:root_path) { "/tmp/converter-root" }
    let(:expected_db_path) { File.expand_path("sub/intermediate.db", root_path) }
    let(:schema_path) { Migrations::Database::INTERMEDIATE_DB_SCHEMA_PATH }
    let(:shard_manager) { instance_double(Migrations::Conversion::ShardManager) }
    let(:writer) { instance_double(Migrations::Database::Connection) }

    before do
      allow(Migrations).to receive(:root_path).and_return(root_path)
      allow(Migrations::Database).to receive(:migrate)
      allow(Migrations::Conversion::ShardManager).to receive(:new).and_return(shard_manager)
      allow(Migrations::Database::Connection).to receive(:new).and_return(writer)
      allow(Migrations::Database::IntermediateDB).to receive(:setup)
    end

    it "migrates the intermediate DB and wires up the shard manager and writer" do
      converter.send(:create_database)

      expect(Migrations::Database).to have_received(:migrate).with(
        expected_db_path,
        migrations_path: schema_path,
      )
      expect(Migrations::Conversion::ShardManager).to have_received(:new).with(
        canonical_path: expected_db_path,
        migrations_path: schema_path,
      )
      expect(Migrations::Database::Connection).to have_received(:new).with(path: expected_db_path)
      expect(Migrations::Database::IntermediateDB).to have_received(:setup).with(writer)

      expect(converter.instance_variable_get(:@shard_manager)).to be(shard_manager)
      expect(converter.instance_variable_get(:@writer)).to be(writer)
    end
  end

  describe "#create_step" do
    let(:settings) { { intermediate_db: { path: "intermediate.db" } } }

    let(:step_class) do
      Class.new do
        attr_reader :received_args

        def initialize(args)
          @received_args = args
        end
      end
    end

    let(:converter_class) do
      Class.new(Migrations::Conversion::Base) do
        # Uses its argument so the test can tell `step_args(step_class)` apart
        # from a call that drops or swaps it.
        def step_args(step_class)
          { step_marker: step_class }
        end
      end
    end

    it "builds the step with settings merged with the per-step args" do
      converter = converter_class.new(settings)

      step = converter.send(:create_step, step_class)

      expect(step).to be_an_instance_of(step_class)
      expect(step.received_args).to eq(settings: settings, step_marker: step_class)
    end
  end

  describe "#steps" do
    subject(:converter) { TemporaryConverterModule::Converter.new(nil) }

    before do
      Object.const_set(
        "TemporaryConverterModule",
        Module.new do
          const_set("Converter", Class.new(Migrations::Conversion::Base))
          const_set("Categories", Class.new(Migrations::Conversion::Step))
          const_set("Topics", Class.new(Migrations::Conversion::Step))
          const_set("Users", Class.new(Migrations::Conversion::Step))
          const_set("SomeHelper", Class.new)
          # A non-class constant: `steps` must skip it before comparing it with
          # `Step`, otherwise `constant < Step` blows up.
          const_set("VERSION", "1.0")
        end,
      )
    end

    after { Object.send(:remove_const, "TemporaryConverterModule") }

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
