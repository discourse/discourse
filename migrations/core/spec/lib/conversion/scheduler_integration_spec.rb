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
      @writer = Migrations::Database::DbWriter.new(path: @db_path)
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
                all.select { |it| it[:id] >= lower && (upper.nil? || it[:id] < upper) }
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

    expect(rows("topics")).to eq((0..59).to_a)
  ensure
    Object.send(:remove_const, "TempIntegrationSteps")
  end

  # The coordinator sizes the fork count from the boundaries, not the budget:
  # `worker_count = [boundaries.size, 1].max`. These two cases exercise the
  # collapse to a single worker.
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
                all.select { |it| it[:id] >= lower && (upper.nil? || it[:id] < upper) }
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
                all.select { |it| it[:id] >= lower && (upper.nil? || it[:id] < upper) }
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

  it "adds new rows to an existing IntermediateDB without dropping or overwriting" do
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
                # id 1 collides with the existing row; id 2 is new
                [{ id: 1, label: "new" }, { id: 2, label: "added" }]
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
    reporter.close

    Migrations::Database::IntermediateDB.close

    db = Extralite::Database.new(@db_path)
    keyed = db.query_array("SELECT id, label FROM keyed ORDER BY id")
    db.close
    # the existing row is kept as-is (not overwritten), and the new row is added
    expect(keyed).to eq([[1, "existing"], [2, "added"]])
  ensure
    Object.send(:remove_const, "TempIntegrationSteps")
  end
end
