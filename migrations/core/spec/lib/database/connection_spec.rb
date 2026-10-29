# frozen_string_literal: true

RSpec.describe Migrations::Database::Connection do
  def create_connection(**params)
    Dir.mktmpdir do |storage_path|
      db_path = File.join(storage_path, "test.db")
      connection = described_class.new(path: db_path, **params)

      return connection if !block_given?

      begin
        yield connection
      ensure
        connection.close if connection
      end
    end
  end

  describe "class" do
    subject(:connection) { create_connection }

    after { connection.close }

    it_behaves_like "a database connection"
  end

  describe ".open_database" do
    it "creates a database at the given path " do
      Dir.mktmpdir do |storage_path|
        db_path = File.join(storage_path, "test.db")
        db = described_class.open_database(path: db_path)

        expect(File.exist?(db_path)).to be true
        expect(db.pragma("journal_mode")).to eq("wal")
        expect(db.pragma("locking_mode")).to eq("normal")
      ensure
        db.close if db
      end
    end
  end

  describe "#close" do
    it "closes the underlying database" do
      create_connection do |connection|
        db = connection
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

        connection.insert("INSERT INTO foo (id) VALUES (?)", [1])
        connection.insert("INSERT INTO foo (id) VALUES (?)", [2])
        expect(db.query_single_splat("SELECT COUNT(*) FROM foo")).to eq(0)

        connection.close
        expect(db.query_single_splat("SELECT COUNT(*) FROM foo")).to eq(2)

        db.close
      end
    end
  end

  describe "#closed?" do
    it "correctly reports if connection is closed" do
      create_connection do |connection|
        expect(connection.closed?).to be false
        connection.close
        expect(connection.closed?).to be true
      end
    end
  end

  describe "#insert" do
    it "keeps cached shard inserts protected by the connection's fork policy" do
      create_connection do |connection|
        connection.execute("CREATE TABLE records (id INTEGER)")
        connection.insert("INSERT INTO records VALUES (?)", [1])
        connection.commit_transaction

        expect { Migrations::ForkManager.fork {} }.to raise_error(
          Migrations::Database::Lifecycle::UnsafeForkError,
        )
        connection.insert("INSERT INTO records VALUES (?)", [2])
        expect(connection.query_splat("SELECT id FROM records ORDER BY id")).to eq([1, 2])
        connection.close
        expect { connection.insert("INSERT INTO records VALUES (?)", [3]) }.to raise_error(
          Migrations::Database::ManagedConnection::UnavailableError,
        )
      end
    end

    it "commits inserted rows when reaching `batch_size`" do
      transaction_batch_size = 3

      create_connection(transaction_batch_size:) do |connection|
        db = described_class.open_database(path: connection.path)
        db.execute("CREATE TABLE foo (id INTEGER)")

        1.upto(10) do |index|
          connection.insert("INSERT INTO foo (id) VALUES (?)", [index])

          expected_count = index / transaction_batch_size * transaction_batch_size
          expect(db.query_single_splat("SELECT COUNT(*) FROM foo")).to eq(expected_count)
        end

        db.close
      end
    end

    it "works with one and more parameters" do
      transaction_batch_size = 1

      create_connection(transaction_batch_size:) do |connection|
        db = described_class.open_database(path: connection.path)
        db.execute("CREATE TABLE foo (id INTEGER)")
        db.execute("CREATE TABLE bar (id INTEGER, name TEXT)")

        connection.insert("INSERT INTO foo (id) VALUES (?)", [1])
        connection.insert("INSERT INTO bar (id, name) VALUES (?, ?)", [1, "Alice"])

        expect(db.query_splat("SELECT id FROM foo")).to contain_exactly(1)
        expect(db.query("SELECT id, name FROM bar")).to contain_exactly({ id: 1, name: "Alice" })

        db.close
      end
    end
  end

  describe "#attach_database" do
    it "commits pending inserts and safely quotes the database name" do
      create_connection do |connection|
        connection.execute("CREATE TABLE values_before_attach (id INTEGER)")
        connection.insert("INSERT INTO values_before_attach VALUES (?)", [1])

        connection.attach_database(":memory:", name: 'source"db')

        expect(connection.transaction_active?).to be false
        expect(connection.query_value("SELECT COUNT(*) FROM values_before_attach")).to eq(1)
        expect(
          connection.query_value(
            "SELECT COUNT(*) FROM pragma_database_list WHERE name = ?",
            'source"db',
          ),
        ).to eq(1)
      end
    end
  end

  describe "#merge_database" do
    def create_schema(db)
      db.execute(<<~SQL)
        CREATE TABLE topic_tags (topic_id INTEGER, tag_id INTEGER, PRIMARY KEY (topic_id, tag_id))
      SQL
      db.execute("CREATE TABLE uploads (id TEXT PRIMARY KEY, filename TEXT)")
    end

    # Yields a run-DB `connection` and a closed shard database at `source_path`,
    # both carrying the same schema. The block seeds each and runs the merge.
    def with_merge_dbs
      Dir.mktmpdir do |dir|
        source_path = File.join(dir, "source.db")
        connection = described_class.new(path: File.join(dir, "main.db"))
        create_schema(connection)

        source = described_class.open_database(path: source_path)
        create_schema(source)

        yield connection, source, source_path
      ensure
        connection&.close
      end
    end

    it "merges non-colliding rows from every listed table" do
      with_merge_dbs do |connection, source, source_path|
        connection.execute("INSERT INTO topic_tags VALUES (1, 10)")
        source.execute("INSERT INTO topic_tags VALUES (2, 20)")
        source.execute("INSERT INTO uploads VALUES ('a', 'a.png')")
        source.close

        connection.merge_database(source_path, tables: %w[topic_tags uploads])

        expect(connection.query("SELECT topic_id, tag_id FROM topic_tags")).to contain_exactly(
          { topic_id: 1, tag_id: 10 },
          { topic_id: 2, tag_id: 20 },
        )
        expect(connection.query_splat("SELECT id FROM uploads")).to contain_exactly("a")
      end
    end

    it "dedups an `OR IGNORE` table across shards, keeping the first writer's row" do
      with_merge_dbs do |connection, source, source_path|
        connection.execute("INSERT INTO uploads VALUES ('x', 'first.png')")
        source.execute("INSERT INTO uploads VALUES ('x', 'second.png')")
        source.close

        connection.merge_database(source_path, tables: %w[uploads], dedupe_tables: %w[uploads])

        expect(connection.query("SELECT id, filename FROM uploads")).to contain_exactly(
          { id: "x", filename: "first.png" },
        )
      end
    end

    it "raises, naming the table, when a plain table has a cross-shard duplicate" do
      with_merge_dbs do |connection, source, source_path|
        connection.execute("INSERT INTO topic_tags VALUES (1, 10)")
        source.execute("INSERT INTO topic_tags VALUES (1, 10)")
        source.close

        expect { connection.merge_database(source_path, tables: %w[topic_tags]) }.to raise_error(
          /topic_tags/,
        )
      end
    end

    it "detaches the merge source even when a merge raises, so the next merge works" do
      with_merge_dbs do |connection, source, source_path|
        connection.execute("INSERT INTO topic_tags VALUES (1, 10)")
        source.execute("INSERT INTO topic_tags VALUES (1, 10)")
        source.close

        expect { connection.merge_database(source_path, tables: %w[topic_tags]) }.to raise_error(
          /topic_tags/,
        )

        # A leaked `merge_source` attachment would make this second merge raise.
        expect { connection.merge_database(source_path, tables: %w[uploads]) }.not_to raise_error
      end
    end
  end

  context "when workers fork" do
    it "prohibits forks by default" do
      create_connection do |connection|
        expect { Migrations::ForkManager.fork {} }.to raise_error(
          Migrations::Database::Lifecycle::UnsafeForkError,
        )
        expect(connection.query_value("SELECT 1")).to eq(1)
      end
    end

    it "closes a reopenable connection before each fork and restores it in the parent" do
      create_connection(reopenable: true) do |connection|
        connection.execute("CREATE TABLE foo (id INTEGER)")
        connection.insert("INSERT INTO foo VALUES (?)", [1])
        connection.commit_transaction

        2.times do
          expect(in_migration_worker { connection.closed? }).to be(true)
          expect(connection.query_splat("SELECT id FROM foo")).to eq([1])
          expect(connection.query_value("PRAGMA integrity_check")).to eq("ok")
        end
      end
    end

    it "rejects an active transaction without committing it" do
      create_connection(reopenable: true) do |connection|
        connection.execute("CREATE TABLE foo (id INTEGER)")
        connection.insert("INSERT INTO foo VALUES (?)", [1])
        expect { Migrations::ForkManager.fork {} }.to raise_error(
          Migrations::Database::Lifecycle::UnsafeForkError,
          /active transaction/,
        )
        expect(connection).to be_transaction_active
        connection.execute("ROLLBACK")
        expect(connection.count("SELECT COUNT(*) FROM foo")).to eq(0)
      end
    end

    it "rejects attached databases and temporary schema" do
      create_connection(reopenable: true) do |connection|
        connection.attach_database(":memory:", name: "attached")
        expect { Migrations::ForkManager.fork {} }.to raise_error(
          Migrations::Database::Lifecycle::UnsafeForkError,
        )
        connection.execute("DETACH DATABASE attached")
        connection.execute("CREATE TEMP TABLE retained (id INTEGER)")
        expect { Migrations::ForkManager.fork {} }.to raise_error(
          Migrations::Database::Lifecycle::UnsafeForkError,
        )
        expect(connection.query_value("SELECT COUNT(*) FROM retained")).to eq(0)
      end
    end

    it "waits for an active SQLite query before closing for a fork" do
      create_connection(reopenable: true) do |connection|
        entered, release = Queue.new, Queue.new
        reader =
          Thread.new do
            connection.query("SELECT 1") do
              entered << true
              release.pop
            end
          end
        entered.pop
        forker = Thread.new { in_migration_worker { connection.closed? } }
        wait_until_stopped(forker)
        expect(forker).to be_alive
        release << true
        reader.value
        expect(forker.value).to be(true)
        expect(connection.query_value("SELECT 2")).to eq(2)
      ensure
        release << true
        reader&.join
        forker&.join
      end
    end
  end
end
