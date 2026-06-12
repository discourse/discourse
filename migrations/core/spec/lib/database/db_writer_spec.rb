# frozen_string_literal: true

RSpec.describe Migrations::Database::DbWriter do
  def create_db_writer
    Dir.mktmpdir do |storage_path|
      db_path = File.join(storage_path, "test.db")

      db = Extralite::Database.new(db_path)
      db.execute("CREATE TABLE foo (id INTEGER)")
      db.close

      db_writer = described_class.new(path: db_path)

      return db_writer if !block_given?

      begin
        yield db_writer, db_path
      ensure
        begin
          db_writer.close
        rescue described_class::WriteError
          # already surfaced by the example
        end
      end
    end
  end

  def insert(db_writer, id)
    db_writer.insert("INSERT INTO foo (id) VALUES (?)", [id])
  end

  def all_ids(db_path)
    db = Extralite::Database.new(db_path)
    db.query_splat("SELECT id FROM foo ORDER BY rowid")
  ensure
    db.close if db
  end

  describe "class" do
    subject(:db_writer) { create_db_writer }

    after { db_writer.close }

    it_behaves_like "a database connection"
  end

  describe "#initialize" do
    it "leaks no fork hooks when the connection cannot be opened" do
      allow(Migrations::Database::Connection).to receive(:new).and_raise(
        Extralite::Error,
        "unable to open database file",
      )

      expect { described_class.new(path: "unused.db") }.to raise_error(Extralite::Error)
      expect(Migrations::ForkManager.size).to eq(0)
    end
  end

  describe "#insert" do
    it "executes statements in enqueue order" do
      create_db_writer do |db_writer, db_path|
        ids = (1..1_000).to_a
        ids.each { |id| insert(db_writer, id) }
        db_writer.close

        expect(all_ids(db_path)).to eq(ids)
      end
    end

    it "never executes statements on the caller thread" do
      create_db_writer do |db_writer|
        connection = db_writer.instance_variable_get(:@connection)
        thread_names = []

        allow(connection).to receive(:insert).and_wrap_original do |original, *args|
          thread_names << Thread.current.name
          original.call(*args)
        end

        insert(db_writer, 1)
        db_writer.flush

        expect(thread_names).to eq(["db_writer"])
      end
    end

    it "raises after close" do
      create_db_writer do |db_writer|
        db_writer.close
        expect { insert(db_writer, 1) }.to raise_error(described_class::ClosedError)
      end
    end
  end

  describe "#flush" do
    it "guarantees that all enqueued statements have been executed" do
      create_db_writer do |db_writer, db_path|
        connection = db_writer.instance_variable_get(:@connection)

        1.upto(10) { |id| insert(db_writer, id) }
        db_writer.flush

        # executed within the writer's open, batched transaction…
        expect(connection.query_value("SELECT COUNT(*) FROM foo")).to eq(10)

        # …but not necessarily committed and visible to other connections yet
        expect(all_ids(db_path)).to be_empty
      end
    end

    it "raises after close" do
      create_db_writer do |db_writer|
        db_writer.close
        expect { db_writer.flush }.to raise_error(described_class::ClosedError)
      end
    end
  end

  describe "#close" do
    it "commits all statements and makes them visible to other connections" do
      create_db_writer do |db_writer, db_path|
        1.upto(10) { |id| insert(db_writer, id) }
        db_writer.close

        expect(all_ids(db_path)).to eq((1..10).to_a)
      end
    end

    it "can be called multiple times" do
      create_db_writer do |db_writer|
        insert(db_writer, 1)
        db_writer.close
        expect { db_writer.close }.not_to raise_error
        expect(db_writer.closed?).to be true
      end
    end

    it "cleans up all fork hooks" do
      expect(Migrations::ForkManager.size).to eq(0)

      create_db_writer do |db_writer|
        # pause/resume hooks of the writer plus the connection's own hook pair
        expect(Migrations::ForkManager.size).to eq(4)
        db_writer.close
        expect(Migrations::ForkManager.size).to eq(0)
      end
    end
  end

  describe "error propagation" do
    it "surfaces a failed statement on the next `insert`, `flush` or `close`" do
      create_db_writer do |db_writer|
        db_writer.insert("INSERT INTO missing_table (id) VALUES (?)", [1])

        expect { db_writer.flush }.to raise_error(described_class::WriteError) do |error|
          expect(error.cause).to be_a(Extralite::Error)
        end

        expect { insert(db_writer, 1) }.to raise_error(described_class::WriteError)

        # `close` re-raises, but still cleans up without hanging
        expect { db_writer.close }.to raise_error(described_class::WriteError)
        expect(db_writer.closed?).to be true
        expect(Migrations::ForkManager.size).to eq(0)
      end
    end
  end

  context "when `Migrations::ForkManager` creates forks" do
    it "drains and parks the writer thread for the duration of the fork window" do
      create_db_writer do |db_writer, db_path|
        connection = db_writer.instance_variable_get(:@connection)

        1.upto(5) { |id| insert(db_writer, id) }

        Migrations::ForkManager.batch_forks do
          # the writer parked before the connection's own before-fork hook
          # committed and closed the database, so all previous statements
          # are visible to other connections
          expect(connection.closed?).to be true
          expect(all_ids(db_path)).to eq((1..5).to_a)

          # producers may keep enqueueing while paused
          insert(db_writer, 6)
          expect(all_ids(db_path)).to eq((1..5).to_a)
        end

        expect(connection.closed?).to be false

        db_writer.close
        expect(all_ids(db_path)).to eq((1..6).to_a)
      end
    end

    it "loses nothing across repeated fork windows with concurrent producers" do
      create_db_writer do |db_writer, db_path|
        producers =
          Array.new(3) do |index|
            Thread.new do
              offset = index * 10_000
              1.upto(2_000) { |id| insert(db_writer, offset + id) }
            end
          end

        fork_windows = 0
        while producers.any?(&:alive?) || fork_windows < 50
          Migrations::ForkManager.batch_forks {}
          fork_windows += 1
        end
        producers.each(&:join)

        db_writer.close

        ids = all_ids(db_path)
        expect(ids.size).to eq(6_000)

        # per-producer FIFO order survives every pause/resume cycle
        3.times do |index|
          offset = index * 10_000
          producer_ids = ids.select { |id| id > offset && id <= offset + 2_000 }
          expect(producer_ids).to eq(((offset + 1)..(offset + 2_000)).to_a)
        end
      end
    end

    it "loses no statements when producers enqueue concurrently with a fork" do
      create_db_writer do |db_writer, db_path|
        producer = Thread.new { 1.upto(500) { |id| insert(db_writer, id) } }

        child_pid = nil
        Migrations::ForkManager.batch_forks do
          child_pid =
            Migrations::ForkManager.fork do
              # in the child all writer methods are pid-guarded no-ops

              insert(db_writer, 9_999)
              db_writer.flush
              db_writer.close
              exit!(0)
            rescue Exception
              exit!(1)
            end
        end

        producer.join
        Process.wait(child_pid)
        expect($?.exitstatus).to eq(0)

        db_writer.close
        expect(all_ids(db_path)).to eq((1..500).to_a)
      end
    end
  end
end
