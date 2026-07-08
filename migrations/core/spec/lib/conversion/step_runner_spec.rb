# frozen_string_literal: true

require "extralite"

class RecordingReporter
  attr_reader :progress, :warnings, :errors

  def initialize
    @progress = @warnings = @errors = 0
  end

  def report_progress(progress:, warnings:, errors:)
    @progress += progress
    @warnings += warnings
    @errors += errors
  end
end

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
