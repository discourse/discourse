# frozen_string_literal: true

require "extralite"
require "timeout"

RSpec.describe Migrations::Conversion::StepScheduler, :integration do
  around do |example|
    Dir.mktmpdir do |storage_path|
      @db_path = File.join(storage_path, "intermediate.db")
      migrations_path = File.join(storage_path, "migrations")
      FileUtils.mkdir_p(migrations_path)
      File.write(File.join(migrations_path, "001-schema.sql"), <<~SQL)
        CREATE TABLE topics (id INTEGER);
        CREATE TABLE users (id INTEGER);
        CREATE TABLE notes (id INTEGER, body TEXT NOT NULL);
        CREATE TABLE keyed (id INTEGER PRIMARY KEY, label TEXT);
        CREATE TABLE log_entries (created_at TEXT, type INTEGER, message TEXT, exception TEXT, details TEXT);
      SQL
      Migrations::Database.migrate(@db_path, migrations_path:)

      # The shard template is migrated fresh from the same schema (no data), so
      # shards stay empty even when the run DB already has rows.
      @shard_manager =
        Migrations::Conversion::ShardManager.new(canonical_path: @db_path, migrations_path:)
      @writer = Migrations::Database::Connection.new(path: @db_path)
      Migrations::Database::IntermediateDB.setup(@writer)
      begin
        example.run
      ensure
        Migrations::Database::IntermediateDB.close
        @shard_manager.cleanup
      end
    end
  end

  def rows(table)
    db = Extralite::Database.new(@db_path)
    db.query_splat("SELECT id FROM #{table} ORDER BY id")
  ensure
    db.close if db
  end

  def log_entry_count
    db = Extralite::Database.new(@db_path)
    db.query_single_splat("SELECT COUNT(*) FROM log_entries")
  ensure
    db.close if db
  end

  def log_messages
    db = Extralite::Database.new(@db_path)
    db.query_splat("SELECT message FROM log_entries ORDER BY message")
  ensure
    db.close if db
  end

  # A reporter that keeps only the latest warning tally per step title, so a test
  # can assert the reducer's warning count reached the reporter. Both live
  # reporters route progress the same way, so recording the shared call is enough.
  let(:recording_reporter_class) do
    Class.new(Migrations::Reporting::Reporter) do
      attr_reader :warnings_by_title, :errors_by_title

      def initialize
        super
        @titles = {}
        @warnings_by_title = {}
        @errors_by_title = {}
        @lock = Mutex.new
      end

      def report_start(id, title)
        @lock.synchronize { @titles[id] = title }
      end

      def report_progress(id, _current, _skip_count, warning_count, error_count)
        @lock.synchronize do
          @warnings_by_title[@titles[id]] = warning_count
          @errors_by_title[@titles[id]] = error_count
        end
      end

      def report_notice(_id, _message)
      end

      def report_progress_begin(_id, _max_progress)
      end

      def report_concurrency(_id, _count)
      end

      def report_finish(_id, _outcome)
      end
    end
  end

  it "writes every row from two steps running concurrently" do
    Object.const_set(
      "TempIntegrationSteps",
      Module.new do
        const_set(
          "Topics",
          Class.new(Migrations::Conversion::Step) do
            source do
              def max_progress
                50
              end

              def items
                Array.new(50) { |index| { id: index } }
              end
            end

            processor do
              def process(item)
                Migrations::Database::IntermediateDB.insert(
                  "INSERT INTO topics (id) VALUES (?)",
                  item[:id],
                )
              end
            end
          end,
        )
        const_set(
          "Users",
          Class.new(Migrations::Conversion::Step) do
            source do
              def max_progress
                5
              end

              def items
                Array.new(5) { |index| { id: index } }
              end
            end

            processor do
              def process(item)
                Migrations::Database::IntermediateDB.insert(
                  "INSERT INTO users (id) VALUES (?)",
                  item[:id],
                )
              end
            end
          end,
        )
      end,
    )

    step_classes = [TempIntegrationSteps::Topics, TempIntegrationSteps::Users]
    reporter = Migrations::Reporting::Factory.build(titles: step_classes.map(&:title))

    expect do
      Migrations::Conversion::StepScheduler.new(
        step_classes:,
        budget: 2,
        reporter:,
        step_factory: ->(step_class) { step_class.new },
        shard_manager: @shard_manager,
        writer: @writer,
      ).run
    ensure
      reporter&.close
    end.to output(/Converting topics/).to_stdout_from_any_process

    # IntermediateDB writes are batched in a transaction; commit before reading
    Migrations::Database::IntermediateDB.close

    expect(rows("topics")).to eq((0..49).to_a)
    expect(rows("users")).to eq((0..4).to_a)
  ensure
    Object.send(:remove_const, "TempIntegrationSteps")
  end

  it "splits a partitioned step across forks and merges every slice" do
    Object.const_set(
      "TempIntegrationSteps",
      Module.new do
        const_set(
          "Topics",
          Class.new(Migrations::Conversion::Step) do
            source do
              partition_by :id, from: "topics"

              def all
                Array.new(60) { |index| { id: index } }
              end

              # Give the coordinator `count` chunk lower bounds (the adapter does
              # this for a real source); each fork reads only its own `[lower, upper)`.
              def partition_boundaries(count)
                size = (all.size.to_f / count).ceil
                (0...count).map { |i| i * size }
              end

              def items
                return all unless chunk

                lower, upper = chunk
                all.select do |it|
                  (lower.nil? || it[:id] >= lower) && (upper.nil? || it[:id] < upper)
                end
              end

              def max_progress
                items.size
              end
            end

            processor do
              def process(item)
                Migrations::Database::IntermediateDB.insert(
                  "INSERT INTO topics (id) VALUES (?)",
                  item[:id],
                )
              end
            end
          end,
        )
      end,
    )

    step_classes = [TempIntegrationSteps::Topics]
    reporter = Migrations::Reporting::Factory.build(titles: step_classes.map(&:title))
    allow(Migrations::Conversion::ChunkQueue).to receive(:filled).and_call_original

    Migrations::Conversion::StepScheduler.new(
      step_classes:,
      budget: 4,
      reporter:,
      step_factory: ->(step_class) { step_class.new },
      shard_manager: @shard_manager,
      writer: @writer,
    ).run
    reporter.close

    Migrations::Database::IntermediateDB.close

    # 3 forks (budget − 1), each over-partitioned into CHUNKS_PER_FORK chunks.
    chunks = 3 * Migrations::Conversion::StepCoordinator::CHUNKS_PER_FORK
    expect(Migrations::Conversion::ChunkQueue).to have_received(:filled).with(chunks)
    expect(rows("topics")).to eq((0..59).to_a)
  ensure
    Object.send(:remove_const, "TempIntegrationSteps")
  end

  # The coordinator caps the fork count at the number of chunks, so a source with
  # fewer chunks than forks runs on fewer workers. These two cases exercise the
  # collapse to a single worker and to none.
  it "collapses to one worker when a partitioned source yields fewer chunks than forks" do
    Object.const_set(
      "TempIntegrationSteps",
      Module.new do
        const_set(
          "Topics",
          Class.new(Migrations::Conversion::Step) do
            source do
              partition_by :id, from: "topics"

              def all
                Array.new(3) { |index| { id: index } }
              end

              # Only one boundary, though more forks are free.
              def partition_boundaries(_count)
                [0]
              end

              def items
                return all unless chunk

                lower, upper = chunk
                all.select do |it|
                  (lower.nil? || it[:id] >= lower) && (upper.nil? || it[:id] < upper)
                end
              end

              def max_progress
                items.size
              end
            end

            processor do
              def process(item)
                Migrations::Database::IntermediateDB.insert(
                  "INSERT INTO topics (id) VALUES (?)",
                  item[:id],
                )
              end
            end
          end,
        )
      end,
    )

    step_classes = [TempIntegrationSteps::Topics]
    reporter = Migrations::Reporting::Factory.build(titles: step_classes.map(&:title))

    Migrations::Conversion::StepScheduler.new(
      step_classes:,
      budget: 4,
      reporter:,
      step_factory: ->(step_class) { step_class.new },
      shard_manager: @shard_manager,
      writer: @writer,
    ).run
    reporter.close

    Migrations::Database::IntermediateDB.close

    expect(rows("topics")).to eq([0, 1, 2]) # every row merged exactly once
  ensure
    Object.send(:remove_const, "TempIntegrationSteps")
  end

  it "runs a single empty worker for a partitioned step over an empty source" do
    Object.const_set(
      "TempIntegrationSteps",
      Module.new do
        const_set(
          "Topics",
          Class.new(Migrations::Conversion::Step) do
            source do
              partition_by :id, from: "topics"

              # No rows, so no boundaries — the coordinator still runs one worker.
              def partition_boundaries(_count)
                []
              end

              def items
                []
              end

              def max_progress
                0
              end
            end

            processor do
              def process(item)
                Migrations::Database::IntermediateDB.insert(
                  "INSERT INTO topics (id) VALUES (?)",
                  item[:id],
                )
              end
            end
          end,
        )
      end,
    )

    step_classes = [TempIntegrationSteps::Topics]
    reporter = Migrations::Reporting::Factory.build(titles: step_classes.map(&:title))

    Migrations::Conversion::StepScheduler.new(
      step_classes:,
      budget: 4,
      reporter:,
      step_factory: ->(step_class) { step_class.new },
      shard_manager: @shard_manager,
      writer: @writer,
    ).run
    reporter.close

    Migrations::Database::IntermediateDB.close

    expect(rows("topics")).to eq([])
  ensure
    Object.send(:remove_const, "TempIntegrationSteps")
  end

  it "runs the step inline, without forking, when no_fork is set" do
    Object.const_set(
      "TempIntegrationSteps",
      Module.new do
        const_set(
          "Topics",
          Class.new(Migrations::Conversion::Step) do
            source do
              partition_by :id, from: "topics"

              def all
                Array.new(20) { |index| { id: index } }
              end

              def partition_boundaries(count)
                size = (all.size.to_f / count).ceil
                (0...count).map { |i| i * size }
              end

              def items
                return all unless chunk

                lower, upper = chunk
                all.select do |it|
                  (lower.nil? || it[:id] >= lower) && (upper.nil? || it[:id] < upper)
                end
              end

              def max_progress
                items.size
              end
            end

            processor do
              def process(item)
                Migrations::Database::IntermediateDB.insert(
                  "INSERT INTO topics (id) VALUES (?)",
                  item[:id],
                )
              end
            end
          end,
        )
      end,
    )

    step_classes = [TempIntegrationSteps::Topics]
    reporter = Migrations::Reporting::Factory.build(titles: step_classes.map(&:title))

    allow(Migrations::ForkManager).to receive(:fork).and_call_original

    Migrations::Conversion::StepScheduler.new(
      step_classes:,
      budget: 4,
      reporter:,
      step_factory: ->(step_class) { step_class.new },
      shard_manager: @shard_manager,
      writer: @writer,
      no_fork: true,
    ).run
    reporter.close

    Migrations::Database::IntermediateDB.close

    expect(Migrations::ForkManager).not_to have_received(:fork)
    expect(rows("topics")).to eq((0..19).to_a)
  ensure
    Object.send(:remove_const, "TempIntegrationSteps")
  end

  it "logs and skips a bad row instead of failing the step" do
    Object.const_set(
      "TempIntegrationSteps",
      Module.new do
        # The middle row's NULL `body` breaks the NOT NULL constraint on insert.
        const_set(
          "Notes",
          Class.new(Migrations::Conversion::Step) do
            source do
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
          end,
        )
        const_set(
          "Users",
          Class.new(Migrations::Conversion::Step) do
            source do
              def items
                Array.new(5) { |index| { id: index } }
              end
            end

            processor do
              def process(item)
                Migrations::Database::IntermediateDB.insert(
                  "INSERT INTO users (id) VALUES (?)",
                  item[:id],
                )
              end
            end
          end,
        )
      end,
    )

    step_classes = [TempIntegrationSteps::Notes, TempIntegrationSteps::Users]
    reporter = Migrations::Reporting::Factory.build(titles: step_classes.map(&:title))

    run =
      lambda do
        Migrations::Conversion::StepScheduler.new(
          step_classes:,
          budget: 2,
          reporter:,
          step_factory: ->(step_class) { step_class.new },
          shard_manager: @shard_manager,
          writer: @writer,
        ).run
      ensure
        reporter&.close
      end

    expect { run.call }.not_to raise_error

    Migrations::Database::IntermediateDB.close

    expect(rows("notes")).to eq([1, 3])
    expect(rows("users")).to eq((0..4).to_a)
    expect(log_entry_count).to eq(1)
  ensure
    Object.send(:remove_const, "TempIntegrationSteps")
  end

  it "fails the step and finishes the run when a worker dies mid-stream" do
    Object.const_set(
      "TempIntegrationSteps",
      Module.new do
        # A worker that exits part-way closes its progress pipe, so the
        # coordinator sees the non-zero exit and discards the half-written shard.
        const_set(
          "Crashing",
          Class.new(Migrations::Conversion::Step) do
            source do
              def items
                Array.new(300) { |index| { id: index } }
              end
            end

            processor do
              def process(item)
                exit!(1) if item[:id] == 150
                Migrations::Database::IntermediateDB.insert(
                  "INSERT INTO topics (id) VALUES (?)",
                  item[:id],
                )
              end
            end
          end,
        )
        const_set(
          "Users",
          Class.new(Migrations::Conversion::Step) do
            source do
              def items
                Array.new(300) { |index| { id: index } }
              end
            end

            processor do
              def process(item)
                Migrations::Database::IntermediateDB.insert(
                  "INSERT INTO users (id) VALUES (?)",
                  item[:id],
                )
              end
            end
          end,
        )
      end,
    )

    step_classes = [TempIntegrationSteps::Crashing, TempIntegrationSteps::Users]
    reporter = Migrations::Reporting::Factory.build(titles: step_classes.map(&:title))

    run =
      lambda do
        Migrations::Conversion::StepScheduler.new(
          step_classes:,
          budget: 2,
          reporter:,
          step_factory: ->(step_class) { step_class.new },
          shard_manager: @shard_manager,
          writer: @writer,
        ).run
      ensure
        reporter&.close
      end

    # `Timeout` turns a hanging run into a failed example instead of a stuck suite.
    expect { Timeout.timeout(30) { run.call } }.to raise_error(Migrations::Conversion::ConvertError)

    Migrations::Database::IntermediateDB.close

    expect(rows("users")).to eq((0..299).to_a)
    # the crashed worker's half-written shard is discarded, not merged
    expect(rows("topics")).to eq([])
  ensure
    Object.send(:remove_const, "TempIntegrationSteps")
  end

  # Runs `TempIntegrationSteps::Keyed`, whose processor writes each item into the
  # `keyed` table. `keyed` has no `INSERT OR IGNORE` model, so its shard merges
  # with a plain, raising `INSERT`.
  def run_keyed_step
    step_classes = [TempIntegrationSteps::Keyed]
    reporter = Migrations::Reporting::Factory.build(titles: step_classes.map(&:title))
    Migrations::Conversion::StepScheduler.new(
      step_classes:,
      budget: 2,
      reporter:,
      step_factory: ->(step_class) { step_class.new },
      shard_manager: @shard_manager,
      writer: @writer,
    ).run
  ensure
    reporter&.close
  end

  it "adds new, non-colliding rows to an existing IntermediateDB" do
    # A row from a previous run already lives in the DB.
    Migrations::Database::IntermediateDB.insert("INSERT INTO keyed VALUES (?, ?)", 1, "existing")

    Object.const_set(
      "TempIntegrationSteps",
      Module.new do
        const_set(
          "Keyed",
          Class.new(Migrations::Conversion::Step) do
            source do
              def items
                # both ids are new; neither collides with the existing row
                [{ id: 2, label: "added" }, { id: 3, label: "more" }]
              end
            end

            processor do
              def process(item)
                Migrations::Database::IntermediateDB.insert(
                  "INSERT INTO keyed VALUES (?, ?)",
                  item[:id],
                  item[:label],
                )
              end
            end
          end,
        )
      end,
    )

    run_keyed_step

    Migrations::Database::IntermediateDB.close

    db = Extralite::Database.new(@db_path)
    keyed = db.query_array("SELECT id, label FROM keyed ORDER BY id")
    db.close
    # the existing row is kept and the new, non-colliding rows are appended
    expect(keyed).to eq([[1, "existing"], [2, "added"], [3, "more"]])
  ensure
    Object.send(:remove_const, "TempIntegrationSteps")
  end

  it "fails the run, naming the table, when a shard row collides with an existing one" do
    # `keyed` merges with a plain `INSERT`, so a shard row that duplicates a row
    # already in the run DB is a genuine double-write: it fails the run loudly
    # instead of being silently dropped, matching the single-writer contract.
    Migrations::Database::IntermediateDB.insert("INSERT INTO keyed VALUES (?, ?)", 1, "existing")

    Object.const_set(
      "TempIntegrationSteps",
      Module.new do
        const_set(
          "Keyed",
          Class.new(Migrations::Conversion::Step) do
            source do
              def items
                [{ id: 1, label: "collides" }] # id 1 already lives in the run DB
              end
            end

            processor do
              def process(item)
                Migrations::Database::IntermediateDB.insert(
                  "INSERT INTO keyed VALUES (?, ?)",
                  item[:id],
                  item[:label],
                )
              end
            end
          end,
        )
      end,
    )

    expect { run_keyed_step }.to raise_error(Migrations::Conversion::ConvertError, /keyed/)
  ensure
    Object.send(:remove_const, "TempIntegrationSteps")
  end

  it "hands every worker's result to the step reducer and feeds its warning count back" do
    Object.const_set(
      "TempIntegrationSteps",
      Module.new do
        const_set(
          "Topics",
          Class.new(Migrations::Conversion::Step) do
            title "Topics"

            source do
              partition_by :id, from: "topics"

              def all
                Array.new(60) { |index| { id: index } }
              end

              def partition_boundaries(count)
                size = (all.size.to_f / count).ceil
                (0...count).map { |i| i * size }
              end

              def items
                return all unless chunk

                lower, upper = chunk
                all.select do |it|
                  (lower.nil? || it[:id] >= lower) && (upper.nil? || it[:id] < upper)
                end
              end

              def max_progress
                items.size
              end
            end

            processor do
              def process(item)
                @count = (@count || 0) + 1
                Migrations::Database::IntermediateDB.insert(
                  "INSERT INTO topics (id) VALUES (?)",
                  item[:id],
                )
              end

              def result
                { "count" => @count } if @count
              end
            end

            def self.combine_results(results, tracker)
              total = results.sum { |result| result["count"] }
              tracker.log_warning("total=#{total}")
              tracker.log_error("reducer error")
            end
          end,
        )
      end,
    )

    step_classes = [TempIntegrationSteps::Topics]
    reporter = recording_reporter_class.new

    Migrations::Conversion::StepScheduler.new(
      step_classes:,
      budget: 4,
      reporter:,
      step_factory: ->(step_class) { step_class.new },
      shard_manager: @shard_manager,
      writer: @writer,
    ).run

    Migrations::Database::IntermediateDB.close

    # Every row is merged, and the workers' results sum to that count — so the
    # reducer saw all of them, none dropped. What the reducer logs through the
    # tracker feeds the step's tallies, warnings and errors alike.
    expect(rows("topics")).to eq((0..59).to_a)
    expect(log_messages).to contain_exactly("total=60", "reducer error")
    expect(reporter.warnings_by_title["Topics"]).to eq(1)
    expect(reporter.errors_by_title["Topics"]).to eq(1)
  ensure
    Object.send(:remove_const, "TempIntegrationSteps")
  end

  it "collects non-nil results and omits workers that returned nil" do
    Object.const_set(
      "TempIntegrationSteps",
      Module.new do
        # Its worker returns a result.
        const_set(
          "WithResult",
          Class.new(Migrations::Conversion::Step) do
            source do
              def items
                [{ id: 1 }]
              end
            end

            processor do
              def process(item)
                Migrations::Database::IntermediateDB.insert(
                  "INSERT INTO topics (id) VALUES (?)",
                  item[:id],
                )
              end

              def result
                { "seen" => true }
              end
            end

            def self.combine_results(results, tracker)
              tracker.log_info("with:#{results.size}")
            end
          end,
        )
        # Its worker returns nil (the default), so nothing lands in the array.
        const_set(
          "Empty",
          Class.new(Migrations::Conversion::Step) do
            source do
              def items
                [{ id: 2 }]
              end
            end

            processor do
              def process(item)
                Migrations::Database::IntermediateDB.insert(
                  "INSERT INTO users (id) VALUES (?)",
                  item[:id],
                )
              end
            end

            def self.combine_results(results, tracker)
              tracker.log_info("empty:#{results.size}")
            end
          end,
        )
      end,
    )

    step_classes = [TempIntegrationSteps::WithResult, TempIntegrationSteps::Empty]
    reporter = Migrations::Reporting::Factory.build(titles: step_classes.map(&:title))

    Migrations::Conversion::StepScheduler.new(
      step_classes:,
      budget: 2,
      reporter:,
      step_factory: ->(step_class) { step_class.new },
      shard_manager: @shard_manager,
      writer: @writer,
    ).run
    reporter.close

    Migrations::Database::IntermediateDB.close

    expect(log_messages).to eq(%w[empty:0 with:1])
  ensure
    Object.send(:remove_const, "TempIntegrationSteps")
  end

  it "does nothing when the step defines no reducer, even if its worker returns a result" do
    Object.const_set(
      "TempIntegrationSteps",
      Module.new do
        const_set(
          "Topics",
          Class.new(Migrations::Conversion::Step) do
            source do
              def items
                [{ id: 1 }, { id: 2 }]
              end
            end

            processor do
              def process(item)
                Migrations::Database::IntermediateDB.insert(
                  "INSERT INTO topics (id) VALUES (?)",
                  item[:id],
                )
              end

              def result
                { "count" => 2 }
              end
            end
          end,
        )
      end,
    )

    step_classes = [TempIntegrationSteps::Topics]
    reporter = Migrations::Reporting::Factory.build(titles: step_classes.map(&:title))

    Migrations::Conversion::StepScheduler.new(
      step_classes:,
      budget: 2,
      reporter:,
      step_factory: ->(step_class) { step_class.new },
      shard_manager: @shard_manager,
      writer: @writer,
    ).run
    reporter.close

    Migrations::Database::IntermediateDB.close

    # The result is collected and simply discarded: no reducer, no log entry.
    expect(rows("topics")).to eq([1, 2])
    expect(log_entry_count).to eq(0)
  ensure
    Object.send(:remove_const, "TempIntegrationSteps")
  end

  it "calls the reducer inline, without forking" do
    Object.const_set(
      "TempIntegrationSteps",
      Module.new do
        const_set(
          "Topics",
          Class.new(Migrations::Conversion::Step) do
            title "Topics"

            source do
              def items
                [{ id: 1 }, { id: 2 }, { id: 3 }]
              end
            end

            processor do
              def process(item)
                @count = (@count || 0) + 1
                Migrations::Database::IntermediateDB.insert(
                  "INSERT INTO topics (id) VALUES (?)",
                  item[:id],
                )
              end

              def result
                { "count" => @count } if @count
              end
            end

            def self.combine_results(results, tracker)
              total = results.sum { |result| result["count"] }
              tracker.log_warning("total=#{total}")
            end
          end,
        )
      end,
    )

    step_classes = [TempIntegrationSteps::Topics]
    reporter = recording_reporter_class.new

    allow(Migrations::ForkManager).to receive(:fork).and_call_original

    Migrations::Conversion::StepScheduler.new(
      step_classes:,
      budget: 4,
      reporter:,
      step_factory: ->(step_class) { step_class.new },
      shard_manager: @shard_manager,
      writer: @writer,
      no_fork: true,
    ).run

    Migrations::Database::IntermediateDB.close

    expect(Migrations::ForkManager).not_to have_received(:fork)
    expect(rows("topics")).to eq([1, 2, 3])
    expect(log_messages).to eq(["total=3"])
    expect(reporter.warnings_by_title["Topics"]).to eq(1)
  ensure
    Object.send(:remove_const, "TempIntegrationSteps")
  end
end
