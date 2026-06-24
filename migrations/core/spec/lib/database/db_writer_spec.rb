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
        rescue StandardError
          # a stored write error surfaces on close; the example already asserted it
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
      expect(Migrations::ForkManager.hook_count).to eq(0)
    end
  end

  describe "#insert" do
    it "writes statements in call order, visible after close" do
      create_db_writer do |db_writer, db_path|
        ids = (1..1_000).to_a
        ids.each { |id| insert(db_writer, id) }
        db_writer.close

        expect(all_ids(db_path)).to eq(ids)
      end
    end

    it "writes on the caller's thread, spawning no background thread" do
      create_db_writer do |db_writer|
        thread_count = Thread.list.size
        insert(db_writer, 1)
        expect(Thread.list.size).to eq(thread_count)
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
    it "is a no-op" do
      create_db_writer do |db_writer|
        insert(db_writer, 1)
        expect(db_writer.flush).to be_nil
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

    it "cleans up the connection's fork hooks" do
      expect(Migrations::ForkManager.hook_count).to eq(0)

      create_db_writer do |db_writer|
        # only the connection's own before/after-fork hook pair
        expect(Migrations::ForkManager.hook_count).to eq(2)
        db_writer.close
        expect(Migrations::ForkManager.hook_count).to eq(0)
      end
    end
  end

  describe "error propagation" do
    it "fails fast on a bad statement and keeps failing on the stored error" do
      create_db_writer do |db_writer|
        expect {
          db_writer.insert("INSERT INTO missing_table (id) VALUES (?)", [1])
        }.to raise_error(Extralite::Error)

        # the stored error keeps surfacing
        expect { insert(db_writer, 1) }.to raise_error(Extralite::Error)
        expect { db_writer.flush }.to raise_error(Extralite::Error)

        # close re-raises it but still closes the connection
        expect { db_writer.close }.to raise_error(Extralite::Error)
        expect(db_writer.closed?).to be true
        expect(Migrations::ForkManager.hook_count).to eq(0)
      end
    end
  end

  context "in a forked child process" do
    it "no-ops `insert`/`flush`/`close` and leaves the parent intact" do
      create_db_writer do |db_writer, db_path|
        insert(db_writer, 1)

        child_pid =
          fork do
            insert(db_writer, 999)
            db_writer.flush
            db_writer.close
            exit!(0)
          rescue Exception
            exit!(1)
          end

        Process.wait(child_pid)
        expect($?.exitstatus).to eq(0)

        # parent's writer is untouched; the child's row was never written
        db_writer.close
        expect(all_ids(db_path)).to eq([1])
      end
    end
  end

  context "when `Migrations::ForkManager` opens a fork window" do
    it "commits and reopens via the connection's own hooks, losing nothing" do
      create_db_writer do |db_writer, db_path|
        connection = db_writer.instance_variable_get(:@connection)

        1.upto(5) { |id| insert(db_writer, id) }

        Migrations::ForkManager.with_batched_forks do
          # the connection's own before-fork hook committed and closed it, so
          # earlier statements are visible to other connections
          expect(connection.closed?).to be true
          expect(all_ids(db_path)).to eq((1..5).to_a)
        end

        # reopened after the fork window
        expect(connection.closed?).to be false
        insert(db_writer, 6)

        db_writer.close
        expect(all_ids(db_path)).to eq((1..6).to_a)
      end
    end
  end
end
