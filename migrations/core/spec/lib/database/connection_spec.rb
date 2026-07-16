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
        create_schema(connection.db)

        source = described_class.open_database(path: source_path)
        create_schema(source)

        yield connection, source, source_path
      ensure
        connection&.close
      end
    end

    it "merges non-colliding rows from every listed table" do
      with_merge_dbs do |connection, source, source_path|
        connection.db.execute("INSERT INTO topic_tags VALUES (1, 10)")
        source.execute("INSERT INTO topic_tags VALUES (2, 20)")
        source.execute("INSERT INTO uploads VALUES ('a', 'a.png')")
        source.close

        connection.merge_database(source_path, tables: %w[topic_tags uploads])

        expect(connection.db.query("SELECT topic_id, tag_id FROM topic_tags")).to contain_exactly(
          { topic_id: 1, tag_id: 10 },
          { topic_id: 2, tag_id: 20 },
        )
        expect(connection.db.query_splat("SELECT id FROM uploads")).to contain_exactly("a")
      end
    end

    it "dedups an `OR IGNORE` table across shards, keeping the first writer's row" do
      with_merge_dbs do |connection, source, source_path|
        connection.db.execute("INSERT INTO uploads VALUES ('x', 'first.png')")
        source.execute("INSERT INTO uploads VALUES ('x', 'second.png')")
        source.close

        connection.merge_database(source_path, tables: %w[uploads], dedupe_tables: %w[uploads])

        expect(connection.db.query("SELECT id, filename FROM uploads")).to contain_exactly(
          { id: "x", filename: "first.png" },
        )
      end
    end

    it "raises, naming the table, when a plain table has a cross-shard duplicate" do
      with_merge_dbs do |connection, source, source_path|
        connection.db.execute("INSERT INTO topic_tags VALUES (1, 10)")
        source.execute("INSERT INTO topic_tags VALUES (1, 10)")
        source.close

        expect { connection.merge_database(source_path, tables: %w[topic_tags]) }.to raise_error(
          /topic_tags/,
        )
      end
    end

    it "detaches the merge source even when a merge raises, so the next merge works" do
      with_merge_dbs do |connection, source, source_path|
        connection.db.execute("INSERT INTO topic_tags VALUES (1, 10)")
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

  context "when `Migrations::ForkManager.fork` is used" do
    it "temporarily closes the connection while a process fork is created" do
      create_connection do |connection|
        expect(connection.closed?).to be false

        connection.db.execute("CREATE TABLE foo (id INTEGER)")
        connection.insert("INSERT INTO foo (id) VALUES (?)", [1])
        expect(connection.db.query_splat("SELECT id FROM foo")).to contain_exactly(1)

        db_before_fork = connection.db

        Migrations::ForkManager.fork do
          expect(connection.closed?).to be true
          expect(connection.db).to be_nil
        end

        expect(connection.closed?).to be false
        expect(connection.db).to_not eq(db_before_fork)

        connection.insert("INSERT INTO foo (id) VALUES (?)", [2])
        expect(connection.db.query_splat("SELECT id FROM foo")).to contain_exactly(1, 2)
      end
    end

    it "works with multiple forks" do
      create_connection do |connection|
        expect(connection.closed?).to be false

        Migrations::ForkManager.fork { expect(connection.closed?).to be true }

        expect(connection.closed?).to be false

        Migrations::ForkManager.fork { expect(connection.closed?).to be true }

        expect(connection.closed?).to be false
      end
    end

    it "cleans up fork hooks when connection gets closed" do
      expect(Migrations::ForkManager.hook_count).to eq(0)

      create_connection do |connection|
        expect(Migrations::ForkManager.hook_count).to eq(2)
        connection.close
        expect(Migrations::ForkManager.hook_count).to eq(0)
      end
    end
  end
end
