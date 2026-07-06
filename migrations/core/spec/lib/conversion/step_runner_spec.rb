# frozen_string_literal: true

require "extralite"

RSpec.describe Migrations::Conversion::StepRunner do
  around do |example|
    Dir.mktmpdir do |dir|
      @shard_path = File.join(dir, "shard.db")
      db = Extralite::Database.new(@shard_path)
      db.execute("CREATE TABLE notes (id INTEGER, body TEXT NOT NULL)")
      db.execute(
        "CREATE TABLE log_entries (created_at TEXT, type INTEGER, message TEXT, exception TEXT, details TEXT)",
      )
      db.close

      example.run
    ensure
      Migrations::Database::IntermediateDB.setup(nil)
    end
  end

  class RecordingReporter
    attr_reader :progress, :warnings, :errors, :calls

    def initialize
      @progress = @warnings = @errors = 0
      @calls = []
    end

    def report_progress(progress:, warnings:, errors:)
      @calls << { progress:, warnings:, errors: }
      @progress += progress
      @warnings += warnings
      @errors += errors
    end
  end

  # A step whose behaviour is driven entirely by its items: each item may set the
  # progress its processing reports (`progress:`), raise a given number of
  # warnings (`warnings:`) and blow up (`raise: true`) so the runner logs an
  # error for it. Lets a test dial in the exact per-item stats it needs.
  let(:scripted_step_class) do
    Class.new(Migrations::Conversion::Step) do
      source do
        def items
          settings[:items]
        end
      end

      processor do
        def process(item)
          tracker.progress = item[:progress] if item.key?(:progress)
          item.fetch(:warnings, 0).times { tracker.log_warning("watch out") }
          raise "boom: #{item[:id]}" if item[:raise]
        end
      end
    end
  end

  def run_scripted(items)
    described_class.new(
      step: scripted_step_class.new(settings: { items: }),
      shard_path: @shard_path,
      reporter:,
    ).run
  end

  let(:step_class) do
    Class.new(Migrations::Conversion::Step) do
      source do
        def max_progress
          3
        end

        def items
          [{ id: 1, body: "ok" }, { id: 2, body: nil }, { id: 3, body: "ok" }]
        end
      end

      processor do
        def process(item)
          Migrations::Database::IntermediateDB.insert(
            "INSERT INTO notes (id, body) VALUES (?, ?)",
            item[:id],
            item[:body],
          )
        end
      end
    end
  end

  let(:reporter) { RecordingReporter.new }

  def shard_rows(table)
    db = Extralite::Database.new(@shard_path)
    db.query_splat("SELECT id FROM #{table} ORDER BY id")
  ensure
    db&.close
  end

  def shard_count(table)
    db = Extralite::Database.new(@shard_path)
    db.query_single_splat("SELECT COUNT(*) FROM #{table}")
  ensure
    db&.close
  end

  def log_rows
    db = Extralite::Database.new(@shard_path)
    db.query("SELECT type, message, exception, details FROM log_entries")
  ensure
    db&.close
  end

  it "reads the whole source, writes every good row to the shard, and reports progress" do
    described_class.new(step: step_class.new, shard_path: @shard_path, reporter:).run

    expect(shard_rows("notes")).to eq([1, 3])
    expect(shard_count("log_entries")).to eq(1)

    # the failed row still counts toward progress
    expect(reporter.progress).to eq(3)
    expect(reporter.errors).to eq(1)
  end

  it "closes the source when it's done" do
    step = step_class.new
    allow(step.source).to receive(:cleanup).and_call_original

    described_class.new(step:, shard_path: @shard_path, reporter:).run

    expect(step.source).to have_received(:cleanup)
  end

  it "logs the failing item with its message, exception, and details" do
    described_class.new(step: step_class.new, shard_path: @shard_path, reporter:).run

    expect(log_rows).to match(
      [
        {
          type: "error",
          message: "Failed to process item",
          exception: a_string_including("NOT NULL constraint failed: notes.body"),
          details: %({"id":2,"body":null}),
        },
      ],
    )
  end

  it "runs the processor's setup before reading any item" do
    step_class =
      Class.new(Migrations::Conversion::Step) do
        source do
          def items
            [{ id: 1 }]
          end
        end

        processor do
          def setup
            @body = "from setup"
          end

          def process(item)
            Migrations::Database::IntermediateDB.insert(
              "INSERT INTO notes (id, body) VALUES (?, ?)",
              item[:id],
              @body,
            )
          end
        end
      end

    described_class.new(step: step_class.new, shard_path: @shard_path, reporter:).run

    # setup filled in `@body`, so the row inserts (a NULL body would be a NOT NULL
    # failure logged to `log_entries` and no note row).
    expect(shard_rows("notes")).to eq([1])
    expect(shard_count("log_entries")).to eq(0)
  end

  it "counts and reports the warnings raised while processing" do
    run_scripted([{ id: 1, warnings: 2 }, { id: 2, warnings: 1 }])

    expect(reporter.calls).to eq([{ progress: 2, warnings: 3, errors: 0 }])
  end

  it "reports a running batch once it reaches the report interval, then starts a fresh one" do
    run_scripted([{ id: 1, progress: 400 }, { id: 2, progress: 700 }, { id: 3, progress: 50 }])

    # 400 stays under the 1_000 interval; +700 crosses it and flushes the batch;
    # the last 50 is left over and flushed at the end.
    expect(reporter.calls.map { |c| c[:progress] }).to eq([1100, 50])
  end

  it "flushes the batch exactly at the report interval, not one item later" do
    run_scripted([{ id: 1, progress: 1000 }, { id: 2, progress: 5 }])

    expect(reporter.calls.map { |c| c[:progress] }).to eq([1000, 5])
  end

  it "carries the batch's warnings and errors along with its progress when it flushes mid-run" do
    run_scripted([{ id: 1, progress: 1000, warnings: 1, raise: true }])

    expect(reporter.calls).to eq([{ progress: 1000, warnings: 1, errors: 1 }])
  end

  it "reports a leftover batch of only good rows at the end" do
    run_scripted([{ id: 1 }, { id: 2 }, { id: 3 }])

    expect(reporter.calls).to eq([{ progress: 3, warnings: 0, errors: 0 }])
  end

  it "does not report an empty final batch after a flush lands on the last item" do
    run_scripted([{ id: 1, progress: 1000 }])

    expect(reporter.calls).to eq([{ progress: 1000, warnings: 0, errors: 0 }])
  end

  it "reports a final batch that carries only errors, no progress" do
    run_scripted([{ id: 1, progress: 0, raise: true }])

    expect(reporter.calls).to eq([{ progress: 0, warnings: 0, errors: 1 }])
  end

  it "reports a final batch that carries only warnings, no progress" do
    run_scripted([{ id: 1, progress: 0, warnings: 1 }])

    expect(reporter.calls).to eq([{ progress: 0, warnings: 1, errors: 0 }])
  end

  context "with a partitioned source" do
    let(:partitioned_step_class) do
      Class.new(Migrations::Conversion::Step) do
        source do
          def all
            (1..10).map { |id| { id:, body: "ok" } }
          end

          def items
            return all unless chunk

            lower, upper = chunk
            all.select { |it| (lower.nil? || it[:id] >= lower) && (upper.nil? || it[:id] < upper) }
          end
        end

        processor do
          def process(item)
            Migrations::Database::IntermediateDB.insert(
              "INSERT INTO notes (id, body) VALUES (?, ?)",
              item[:id],
              item[:body],
            )
          end
        end
      end
    end

    def run_with(**read)
      described_class.new(
        step: partitioned_step_class.new,
        shard_path: @shard_path,
        reporter:,
        **read,
      ).run
    end

    it "reads a single chunk" do
      run_with(chunks: [[1, 6]])
      expect(shard_rows("notes")).to eq([1, 2, 3, 4, 5])
    end

    it "reads an open-ended chunk" do
      run_with(chunks: [[6, nil]])
      expect(shard_rows("notes")).to eq([6, 7, 8, 9, 10])
    end

    it "reads every chunk it's given, in turn" do
      run_with(chunks: [[1, 4], [7, 10]])
      expect(shard_rows("notes")).to eq([1, 2, 3, 7, 8, 9])
    end

    it "reads the whole source when open at both ends" do
      run_with(chunks: [[nil, nil]])
      expect(shard_rows("notes")).to eq((1..10).to_a)
    end
  end
end
