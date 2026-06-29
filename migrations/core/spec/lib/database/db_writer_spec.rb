# frozen_string_literal: true

RSpec.describe Migrations::Database::DbWriter do
  def with_db_writer
    Dir.mktmpdir do |storage_path|
      db_path = File.join(storage_path, "test.db")

      db = Extralite::Database.new(db_path)
      db.execute("CREATE TABLE foo (id INTEGER)")
      db.close

      db_writer = described_class.new(path: db_path)

      begin
        yield db_writer, db_path
      ensure
        db_writer.close
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
    subject(:db_writer) do
      Dir.mktmpdir { |storage_path| described_class.new(path: File.join(storage_path, "test.db")) }
    end

    after { db_writer.close }

    it_behaves_like "a database connection"
  end

  describe "#initialize" do
    it "registers no fork hooks when the connection cannot be opened" do
      allow(Migrations::Database::Connection).to receive(:new).and_raise(
        Extralite::Error,
        "unable to open database file",
      )

      expect { described_class.new(path: "unused.db") }.to raise_error(Extralite::Error)
      expect(Migrations::ForkManager.hook_count).to eq(0)
    end
  end

  describe "#insert" do
    it "executes statements on the caller thread, in call order" do
      with_db_writer do |db_writer, db_path|
        connection = db_writer.instance_variable_get(:@connection)
        thread_names = []
        allow(connection).to receive(:insert).and_wrap_original do |original, *args|
          thread_names << Thread.current.name
          original.call(*args)
        end

        ids = (1..1_000).to_a
        ids.each { |id| insert(db_writer, id) }
        db_writer.close

        expect(all_ids(db_path)).to eq(ids)
        expect(thread_names.uniq).to eq([Thread.current.name])
      end
    end

    it "serializes concurrent writers without losing rows" do
      with_db_writer do |db_writer, db_path|
        threads =
          (1..8).map do |worker|
            Thread.new do
              ((worker - 1) * 100 + 1).upto(worker * 100) { |id| insert(db_writer, id) }
            end
          end
        threads.each(&:join)
        db_writer.close

        expect(all_ids(db_path).sort).to eq((1..800).to_a)
      end
    end

    it "does nothing in a forked child process" do
      with_db_writer do |db_writer, db_path|
        pid =
          Process.fork do
            insert(db_writer, 99)
            exit!(0)
          end
        Process.waitpid(pid)

        insert(db_writer, 1)
        db_writer.close

        expect(all_ids(db_path)).to eq([1])
      end
    end

    it "raises a failed insert to its caller but stays usable for later writes" do
      with_db_writer do |db_writer, db_path|
        connection = db_writer.instance_variable_get(:@connection)
        boom = Extralite::Error.new("boom")
        allow(connection).to receive(:insert).and_wrap_original do |original, sql, parameters|
          raise boom if parameters == [1]
          original.call(sql, parameters)
        end

        # the bad row fails, but the writer isn't poisoned: a row from another
        # caller still goes through, so one step can't take down the steps it
        # shares the run-level writer with
        expect { insert(db_writer, 1) }.to raise_error(boom)
        insert(db_writer, 2)
        db_writer.close

        expect(all_ids(db_path)).to eq([2])
      end
    end

    it "raises after close" do
      with_db_writer do |db_writer|
        db_writer.close
        expect { insert(db_writer, 1) }.to raise_error(described_class::ClosedError)
      end
    end
  end

  describe "#close" do
    it "is idempotent" do
      with_db_writer do |db_writer|
        db_writer.close
        expect { db_writer.close }.not_to raise_error
        expect(db_writer).to be_closed
      end
    end

    it "removes the connection's fork hooks" do
      with_db_writer do |db_writer|
        db_writer.close
        expect(Migrations::ForkManager.hook_count).to eq(0)
      end
    end
  end

  describe "fork safety" do
    it "keeps writers out of the connection for the whole fork window" do
      with_db_writer do |db_writer, db_path|
        writer = nil

        Migrations::ForkManager.with_batched_forks do
          # the connection is closed for the whole fork window, so a concurrent
          # write has to wait rather than hit a closed handle
          writer = Thread.new { insert(db_writer, 1) }
          expect(writer.join(0.2)).to be_nil
        end

        writer.join
        db_writer.close
        expect(all_ids(db_path)).to eq([1])
      end
    end
  end
end
