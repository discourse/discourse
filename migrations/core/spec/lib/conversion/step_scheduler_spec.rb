# frozen_string_literal: true

RSpec.describe Migrations::Conversion::StepScheduler do
  let(:events) { Queue.new }

  # Fake StepCoordinator: announces its step, then blocks until the example
  # releases it, so we can drive ordering and concurrency without forking.
  class FakeCoordinator
    attr_reader :step_class

    def initialize(step_class, scheduler, events:, outcome: :done, raise_in_run: false)
      @step_class = step_class
      @scheduler = scheduler
      @events = events
      @outcome = outcome
      @raise_in_run = raise_in_run
      @finish = Queue.new
    end

    def run
      @events << @step_class.name.demodulize
      @finish.pop

      raise "unhandled error in #{@step_class.name.demodulize}" if @raise_in_run

      if @outcome == :failed
        @scheduler.record_failure(
          @step_class,
          RuntimeError.new("boom in #{@step_class.name.demodulize}"),
        )
      end

      @outcome
    end

    def finish!
      @finish << true
    end
  end

  # Builds named step classes in a throwaway namespace so `depends_on` (which
  # resolves names lexically) and the class-name tie-break have real classes to
  # work with. `stub_const` removes them after the example.
  def define_steps(*names, partitionable: [])
    namespace = Module.new
    names.each do |name|
      step_class =
        Class.new(Migrations::Conversion::Step) do
          if partitionable.include?(name)
            source do
              partition_by :id, from: "things"

              def items
                []
              end
            end
          end
        end
      namespace.const_set(name, step_class)
    end
    stub_const("TempSteps", namespace)
    names.map { |name| namespace.const_get(name) }
  end

  def build_scheduler(step_classes, budget: 4, max_parallel_steps: nil, config: {})
    reporter = instance_double(Migrations::Reporting::Reporter)
    allow(reporter).to receive(:finalizing).and_yield
    allow(reporter).to receive(:report_summary)

    scheduler =
      described_class.new(
        step_classes:,
        reporter:,
        step_factory: ->(_step_class) {},
        shard_manager: instance_double(Migrations::Conversion::ShardManager),
        budget:,
        max_parallel_steps:,
      )

    coordinators =
      step_classes.to_h do |step_class|
        options = config[step_class] || {}
        coordinator =
          FakeCoordinator.new(
            step_class,
            scheduler,
            events:,
            outcome: options.fetch(:outcome, :done),
            raise_in_run: options.fetch(:raise_in_run, false),
          )
        [step_class, coordinator]
      end

    allow(scheduler).to receive(:build_coordinator) { |step_class| coordinators.fetch(step_class) }

    by_name = coordinators.transform_keys { |step_class| step_class.name.demodulize }
    [scheduler, by_name]
  end

  def run_in_background(scheduler)
    Thread.new do
      Thread.current.report_on_exception = false
      scheduler.run
    end
  end

  it "starts a step only once its dependencies are done" do
    a, b = define_steps(:A, :B)
    b.depends_on(:a)
    scheduler, by_name = build_scheduler([a, b])

    runner = run_in_background(scheduler)

    expect(events.pop).to eq("A")
    expect(events).to be_empty
    by_name["A"].finish!

    expect(events.pop).to eq("B")
    by_name["B"].finish!

    runner.join
  end

  it "admits ready steps in a deterministic order on an empty graph" do
    steps = define_steps(:C, :A, :B)
    scheduler, by_name = build_scheduler(steps, budget: 1)

    runner = run_in_background(scheduler)

    %w[A B C].each do |name|
      expect(events.pop).to eq(name)
      by_name[name].finish!
    end

    runner.join
  end

  it "never runs more steps at once than the budget" do
    steps = define_steps(:A, :B, :C, :D)
    scheduler, by_name = build_scheduler(steps, budget: 2)

    runner = run_in_background(scheduler)

    expect([events.pop, events.pop].sort).to eq(%w[A B])
    expect(events).to be_empty

    by_name["A"].finish!
    expect(events.pop).to eq("C")
    expect(events).to be_empty

    by_name["B"].finish!
    expect(events.pop).to eq("D")

    by_name["C"].finish!
    by_name["D"].finish!
    runner.join
  end

  it "leaves a fork free for a single-fork step to overlap a partitioned step" do
    big, x, y = define_steps(:Big, :X, :Y, partitionable: %i[Big])
    scheduler, by_name = build_scheduler([big, x, y], budget: 4)

    runner = run_in_background(scheduler)

    # Big takes 3 of the 4 forks, so one single-fork step fills the last fork
    # and overlaps Big instead of queueing behind it.
    expect([events.pop, events.pop].sort).to eq(%w[Big X])
    expect(events).to be_empty
    by_name["X"].finish!

    expect(events.pop).to eq("Y")
    by_name["Big"].finish!
    by_name["Y"].finish!

    runner.join
  end

  it "caps the budget with --max-parallel-steps" do
    steps = define_steps(:A, :B, :C)
    scheduler, by_name = build_scheduler(steps, budget: 8, max_parallel_steps: 1)

    runner = run_in_background(scheduler)

    %w[A B C].each do |name|
      expect(events.pop).to eq(name)
      expect(events).to be_empty
      by_name[name].finish!
    end

    runner.join
  end

  it "skips a failed step's dependents, runs independent steps, and raises a summary" do
    a, b, c = define_steps(:A, :B, :C)
    b.depends_on(:a)

    scheduler, by_name = build_scheduler([a, b, c], config: { a => { outcome: :failed } })

    runner = run_in_background(scheduler)

    expect([events.pop, events.pop].sort).to eq(%w[A C])
    by_name["A"].finish!
    by_name["C"].finish!

    expect { runner.join }.to raise_error(Migrations::Conversion::ConvertError) do |error|
      expect(error.message).to match(/boom in A/)
      expect(error.message).to match(/skipped/)
    end
    expect(events).to be_empty
  end

  it "still finishes when a coordinator raises instead of reporting back" do
    a, b = define_steps(:A, :B)
    scheduler, by_name = build_scheduler([a, b], config: { a => { raise_in_run: true } })

    runner = run_in_background(scheduler)

    expect([events.pop, events.pop].sort).to eq(%w[A B])
    by_name["A"].finish!
    by_name["B"].finish!

    expect { runner.join }.to raise_error(
      Migrations::Conversion::ConvertError,
      /unhandled error in A/,
    )
  end
end
