# frozen_string_literal: true

RSpec.describe Migrations::Database::Connection do
  describe ".open_database" do
    it "creates a database at the given path " do
      Dir.mktmpdir do |storage_path|
        db_path = File.join(storage_path, "test.db")
        db = described_class.open_database(path: db_path)

        expect(File.exist?(db_path)).to eq(true)
        expect(db.pragma("journal_mode")).to eq("wal")
        expect(db.pragma("locking_mode")).to eq("normal")
      ensure
        db.close if db
      end
    end
  end

  def create_connection(**params)
    Dir.mktmpdir do |storage_path|
      db_path = File.join(storage_path, "test.db")
      connection = described_class.new(path: db_path, **params)
      begin
        yield connection
      ensure
        connection.close if connection
      end
    end
  end

  describe "#close" do
    it "closes the underlying database" do
      create_connection do |connection|
        db = connection.db
        connection.close
        expect(db).to be_closed
      end
    end

    it "closes cached prepared statements" do
      cache_class = Migrations::Database::PreparedStatementCache
      cache_double = instance_spy(cache_class)
      allow(cache_class).to receive(:new).and_return(cache_double)

      create_connection do |connection|
        expect(cache_double).not_to have_received(:clear)
        connection.close
        expect(cache_double).to have_received(:clear).once
      end
    end

    it "commits an active transaction" do
      create_connection do |connection|
        db = described_class.open_database(path: connection.path)
        db.execute("CREATE TABLE foo (id INTEGER)")

        connection.insert("INSERT INTO foo (id) VALUES (?)", 1)
        connection.insert("INSERT INTO foo (id) VALUES (?)", 2)
        expect(db.query_single_splat("SELECT COUNT(*) FROM foo")).to eq(0)

        connection.close
        expect(db.query_single_splat("SELECT COUNT(*) FROM foo")).to eq(2)

        db.close
      end
    end
  end

  describe "#insert" do
    it "commits inserted rows when reaching `batch_size`" do
      transaction_batch_size = 3

      create_connection(transaction_batch_size:) do |connection|
        db = described_class.open_database(path: connection.path)
        db.execute("CREATE TABLE foo (id INTEGER)")

        1.upto(10) do |index|
          connection.insert("INSERT INTO foo (id) VALUES (?)", index)

          expected_count = index / transaction_batch_size * transaction_batch_size
          expect(db.query_single_splat("SELECT COUNT(*) FROM foo")).to eq(expected_count)
        end

        db.close
      end
    end
  end
end
