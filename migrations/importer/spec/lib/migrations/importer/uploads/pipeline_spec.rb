# frozen_string_literal: true

RSpec.describe Migrations::Importer::Uploads::Pipeline do
  # Records what the pipeline reports so tests can assert on batching and outcome
  # without a real terminal. Mirrors the small surface the pipeline uses:
  # start_step -> step, step.with_progress { |progress| ... }, notice, finish.
  class FakeProgress
    attr_reader :updates

    def initialize
      @updates = []
      @mutex = Mutex.new
    end

    def update(increment_by:, skip_count: 0, warning_count: 0, error_count: 0)
      @mutex.synchronize do
        @updates << { increment_by:, skip_count:, warning_count:, error_count: }
      end
    end

    def total
      @updates.sum { |u| u[:increment_by] }
    end
  end

  class FakeStep
    attr_reader :progress, :notices, :finished_outcome, :max_progress

    def initialize
      @notices = []
    end

    def notice(message)
      @notices << message
    end

    def with_progress(max_progress:)
      @max_progress = max_progress
      @progress = FakeProgress.new
      yield @progress
    end

    def finish(outcome: nil)
      @finished_outcome = outcome
    end
  end

  class FakeReporter
    attr_reader :step, :closed

    def start_step(_title)
      @step = FakeStep.new
    end

    def close
      @closed = true
    end
  end

  # A pipeline task driven entirely from plain data, so the engine can be tested
  # without Rails. `rows` are the work items; `process` and `write` decide the
  # per-row result and its outcome.
  class FakeTask
    attr_accessor :reporter
    attr_reader :written, :before_run_called, :after_run_called

    def initialize(rows:, worker_count: 4, skip_ids: [], process: nil, write: nil)
      @rows = rows
      @worker_count = worker_count
      @skip_ids = skip_ids
      @process = process || ->(row, _resource) { row }
      @write = write || ->(_result) { :ok }
      @written = []
      @write_mutex = Mutex.new
    end

    def title
      "Fake"
    end

    def worker_count
      @worker_count
    end

    def max_count
      @rows.size
    end

    def before_run
      @before_run_called = true
    end

    def after_run
      @after_run_called = true
    end

    def build_worker_resource
      nil
    end

    def produce(emit_work:, emit_result:)
      @rows.each do |row|
        if @skip_ids.include?(row[:id])
          emit_result.call(row.merge(skipped: true))
        else
          emit_work.call(row)
        end
      end
    end

    def process(row, resource)
      @process.call(row, resource)
    end

    # Runs only on the writer thread, so appending without a lock would be safe;
    # the mutex just keeps the intent obvious.
    def write(result)
      @write_mutex.synchronize { @written << result }
      @write.call(result)
    end
  end

  let(:reporter) { FakeReporter.new }

  def build_pipeline(task, **options)
    described_class.new(
      task:,
      reporter:,
      install_trap: false,
      with_connection: ->(&block) { block.call },
      **options,
    )
  end

  def rows(count)
    Array.new(count) { |i| { id: i } }
  end

  it "runs the task lifecycle and writes every produced row exactly once" do
    task = FakeTask.new(rows: rows(1000), worker_count: 4)

    build_pipeline(task).run

    expect(task.before_run_called).to be(true)
    expect(task.after_run_called).to be(true)
    expect(task.written.map { |r| r[:id] }).to match_array((0...1000).to_a)
    expect(reporter.step.progress.total).to eq(1000)
    expect(reporter.step.finished_outcome).to be_nil # not interrupted -> reporter infers :done
    expect(reporter.step.max_progress).to eq(1000)
  end

  it "batches the producer output and reports progress once per batch" do
    # One worker keeps the order deterministic: 10 rows in batches of 4 arrive as
    # [4, 4, 2], and the writer reports progress once per popped array.
    task = FakeTask.new(rows: rows(10), worker_count: 1)

    build_pipeline(task, batch_size: 4).run

    increments = reporter.step.progress.updates.map { |u| u[:increment_by] }
    expect(increments).to eq([4, 4, 2])
  end

  it "drops rows whose process returns nil, counting only what was written" do
    dropper = ->(row, _resource) { row[:id].even? ? row : nil }
    task = FakeTask.new(rows: rows(100), worker_count: 3, process: dropper)

    build_pipeline(task).run

    written_ids = task.written.map { |r| r[:id] }
    expect(written_ids).to all(be_even)
    expect(written_ids.size).to eq(50)
    expect(reporter.step.progress.total).to eq(50)
  end

  it "routes producer-side results straight to the writer, skipping the workers" do
    # Every row is pre-skipped, so a worker that raises proves none reach it.
    exploding = ->(_row, _resource) { raise "workers should not see skipped rows" }
    skip_ids = [1, 3, 5]
    task =
      FakeTask.new(
        rows: skip_ids.map { |id| { id: } },
        worker_count: 2,
        skip_ids:,
        process: exploding,
      )

    build_pipeline(task).run

    expect(task.written.map { |r| r[:id] }).to match_array(skip_ids)
    expect(task.written).to all(include(skipped: true))
  end

  it "tallies per-result outcomes into the progress counts" do
    classifier = ->(result) do
      case result[:id] % 3
      when 0
        :skip
      when 1
        :error
      else
        :ok
      end
    end
    task = FakeTask.new(rows: rows(9), worker_count: 1, write: classifier)

    build_pipeline(task, batch_size: 9).run

    update = reporter.step.progress.updates.sum { |u| u[:skip_count] }
    errors = reporter.step.progress.updates.sum { |u| u[:error_count] }
    expect(update).to eq(3) # ids 0, 3, 6
    expect(errors).to eq(3) # ids 1, 4, 7
    expect(reporter.step.progress.total).to eq(9)
  end

  describe "interrupt handling" do
    it "sets the flag on the first interrupt and bails out on the second" do
      exits = 0
      task = FakeTask.new(rows: rows(1))
      pipeline = build_pipeline(task, on_double_interrupt: -> { exits += 1 })

      expect(pipeline.interrupted?).to be(false)

      pipeline.handle_interrupt
      expect(pipeline.interrupted?).to be(true)
      expect(exits).to eq(0)

      pipeline.handle_interrupt
      expect(exits).to eq(1)
    end

    it "stops early, drains, and finishes as interrupted when the flag is set" do
      task = FakeTask.new(rows: rows(1000), worker_count: 4)
      pipeline = build_pipeline(task)

      pipeline.handle_interrupt # flag set before the run starts
      pipeline.run # must not hang

      expect(pipeline.interrupted?).to be(true)
      expect(task.written.size).to be < 1000
      expect(reporter.step.finished_outcome).to eq(:interrupted)
      expect(task.after_run_called).to be(true) # still drains and commits
    end
  end
end
