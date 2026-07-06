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
    it "creates a database at the given path and applies every pragma" do
      Dir.mktmpdir do |storage_path|
        db_path = File.join(storage_path, "test.db")
        db = described_class.open_database(path: db_path)

        expect(File.exist?(db_path)).to be true
        expect(db.pragma("busy_timeout")).to eq(60_000)
        expect(db.pragma("journal_mode")).to eq("wal")
        expect(db.pragma("synchronous")).to eq(0) # "off"
        expect(db.pragma("temp_store")).to eq(2) # "memory"
        expect(db.pragma("locking_mode")).to eq("normal")
        expect(db.pragma("cache_size")).to eq(-10_000)
      ensure
        db.close if db
      end
    end

    it "resolves a relative path against the migrations root" do
      Dir.mktmpdir do |root|
        allow(Migrations).to receive(:root_path).and_return(root)

        db = described_class.open_database(path: "sub/test.db")

        expect(File.exist?(File.join(root, "sub/test.db"))).to be true
      ensure
        db.close if db
      end
    end
  end

  describe "#initialize" do
    it "resolves a relative path against the migrations root" do
      Dir.mktmpdir do |root|
        allow(Migrations).to receive(:root_path).and_return(root)

        connection = described_class.new(path: "sub/test.db")
        expect(connection.path).to eq(File.join(root, "sub/test.db"))
      ensure
        connection&.close
      end
    end

    it "opens the database and starts a fresh, uncommitted batch" do
      create_connection do |connection|
        connection.execute("CREATE TABLE foo (id INTEGER)")
        expect { connection.insert("INSERT INTO foo (id) VALUES (?)", [1]) }.not_to raise_error

        # With the default (large) batch size and a zeroed counter, the first
        # insert opens a transaction, so a separate reader can't see it yet.
        reader = described_class.open_database(path: connection.path)
        expect(reader.query_single_splat("SELECT COUNT(*) FROM foo")).to eq(0)
        reader.close
      end
    end

    it "stores the fork hooks so `close` can remove them" do
      baseline = Migrations::ForkManager.hook_count

      create_connection do |connection|
        expect(Migrations::ForkManager.hook_count).to eq(baseline + 2)
        connection.close
        expect(Migrations::ForkManager.hook_count).to eq(baseline)
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

    it "clears the stored path" do
      create_connection do |connection|
        connection.close
        expect(connection.path).to be_nil
      end
    end

    it "removes both fork hooks it registered" do
      baseline = Migrations::ForkManager.hook_count

      create_connection do |connection|
        expect(Migrations::ForkManager.hook_count).to eq(baseline + 2)
        connection.close
        expect(Migrations::ForkManager.hook_count).to eq(baseline)
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

    it "reports closed when the underlying handle is closed but not yet cleared" do
      create_connection do |connection|
        connection.db.close
        expect(connection.closed?).to be true
      ensure
        # The handle is closed but `@db` still points at it; clear it so the
        # shared teardown's `close` does not try to commit on a dead handle.
        connection.instance_variable_set(:@db, nil)
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

    it "defaults `parameters` to an empty list" do
      create_connection do |connection|
        connection.execute("CREATE TABLE foo (id INTEGER DEFAULT 5)")

        expect { connection.insert("INSERT INTO foo DEFAULT VALUES") }.not_to raise_error

        connection.commit_transaction
        expect(connection.query_value("SELECT id FROM foo")).to eq(5)
      end
    end

    it "prepares each distinct statement only once by caching it" do
      create_connection do |connection|
        connection.execute("CREATE TABLE foo (id INTEGER)")
        allow(connection.db).to receive(:prepare).and_call_original

        connection.insert("INSERT INTO foo (id) VALUES (?)", [1])
        connection.insert("INSERT INTO foo (id) VALUES (?)", [2])

        expect(connection.db).to have_received(:prepare).once
      end
    end

    it "returns nil even when the insert triggers a batch commit" do
      create_connection(transaction_batch_size: 1) do |connection|
        connection.execute("CREATE TABLE foo (id INTEGER)")

        expect(connection.insert("INSERT INTO foo (id) VALUES (?)", [1])).to be_nil
      end
    end
  end

  describe "#query" do
    it "runs the SQL with bind parameters and yields each row to the block" do
      create_connection do |connection|
        connection.execute("CREATE TABLE foo (id INTEGER)")
        connection.execute("INSERT INTO foo (id) VALUES (1), (2), (3)")

        yielded = []
        connection.query("SELECT id FROM foo WHERE id BETWEEN ? AND ? ORDER BY id", 1, 2) do |row|
          yielded << row
        end

        expect(yielded).to eq([{ id: 1 }, { id: 2 }])
      end
    end
  end

  describe "#query_array" do
    it "runs the SQL with bind parameters and yields each row as an array" do
      create_connection do |connection|
        connection.execute("CREATE TABLE foo (id INTEGER, name TEXT)")
        connection.execute("INSERT INTO foo VALUES (1, 'a'), (2, 'b'), (3, 'c')")

        yielded = []
        connection.query_array(
          "SELECT id, name FROM foo WHERE id BETWEEN ? AND ? ORDER BY id",
          1,
          2,
        ) { |row| yielded << row }

        expect(yielded).to eq([[1, "a"], [2, "b"]])
      end
    end
  end

  describe "#query_value" do
    it "returns the first value of the first row, honoring bind parameters" do
      create_connection do |connection|
        connection.execute("CREATE TABLE foo (id INTEGER)")
        connection.execute("INSERT INTO foo VALUES (1), (2), (3)")

        expect(
          connection.query_value("SELECT COUNT(*) FROM foo WHERE id BETWEEN ? AND ?", 1, 2),
        ).to eq(2)
      end
    end
  end

  describe "#count" do
    it "returns the value of a counting query, honoring bind parameters" do
      create_connection do |connection|
        connection.execute("CREATE TABLE foo (id INTEGER)")
        connection.execute("INSERT INTO foo VALUES (1), (2), (3)")

        expect(connection.count("SELECT COUNT(*) FROM foo WHERE id BETWEEN ? AND ?", 1, 2)).to eq(2)
      end
    end
  end

  describe "#tables" do
    it "lists the tables in the database" do
      create_connection do |connection|
        connection.execute("CREATE TABLE foo (id INTEGER)")
        connection.execute("CREATE TABLE bar (id INTEGER)")

        expect(connection.tables).to contain_exactly("foo", "bar")
      end
    end
  end

  describe "#execute" do
    it "runs a statement with bind parameters and returns the number of affected rows" do
      create_connection do |connection|
        connection.execute("CREATE TABLE foo (id INTEGER, name TEXT)")

        expect(connection.execute("INSERT INTO foo VALUES (?, ?)", 1, "a")).to eq(1)
        expect(connection.query("SELECT id, name FROM foo")).to contain_exactly(
          { id: 1, name: "a" },
        )
      end
    end
  end

  describe "#begin_transaction" do
    it "does not start a second transaction when one is already active" do
      create_connection do |connection|
        connection.begin_transaction
        expect(connection.db.transaction_active?).to be true

        expect { connection.begin_transaction }.not_to raise_error
      end
    end
  end

  describe "#quote_identifier" do
    it "wraps the identifier in double quotes and escapes every embedded quote" do
      create_connection do |connection|
        expect(connection.send(:quote_identifier, 'a"b"c')).to eq('"a""b""c"')
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

        expect(connection.merge_database(source_path, tables: %w[topic_tags uploads])).to be_nil

        expect(connection.db.query("SELECT topic_id, tag_id FROM topic_tags")).to contain_exactly(
          { topic_id: 1, tag_id: 10 },
          { topic_id: 2, tag_id: 20 },
        )
        expect(connection.db.query_splat("SELECT id FROM uploads")).to contain_exactly("a")
      end
    end

    it "commits an open transaction before attaching, so `ATTACH` can run" do
      with_merge_dbs do |connection, source, source_path|
        source.execute("INSERT INTO uploads VALUES ('a', 'a.png')")
        source.close

        # A plain `insert` opens a transaction (batch size defaults to 1000), and
        # `ATTACH` cannot run inside one.
        connection.insert("INSERT INTO uploads VALUES (?, ?)", %w[b b.png])

        expect { connection.merge_database(source_path, tables: %w[uploads]) }.not_to raise_error
        expect(connection.db.query_splat("SELECT id FROM uploads")).to contain_exactly("a", "b")
      end
    end

    it "quotes table identifiers so a reserved-word table merges cleanly" do
      Dir.mktmpdir do |dir|
        source_path = File.join(dir, "source.db")
        connection = described_class.new(path: File.join(dir, "main.db"))
        connection.db.execute('CREATE TABLE "order" (id INTEGER PRIMARY KEY)')

        source = described_class.open_database(path: source_path)
        source.execute('CREATE TABLE "order" (id INTEGER PRIMARY KEY)')
        source.execute('INSERT INTO "order" VALUES (1)')
        source.close

        connection.merge_database(source_path, tables: ["order"])

        expect(connection.db.query_splat('SELECT id FROM "order"')).to contain_exactly(1)
      ensure
        connection&.close
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

    it "wraps a merge failure in a message naming the table and the underlying error" do
      with_merge_dbs do |connection, source, source_path|
        connection.db.execute("INSERT INTO topic_tags VALUES (1, 10)")
        source.execute("INSERT INTO topic_tags VALUES (1, 10)")
        source.close

        expect { connection.merge_database(source_path, tables: %w[topic_tags]) }.to raise_error(
          RuntimeError,
          /\AFailed to merge table "topic_tags": .*constraint/i,
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

    it "resets the statement counter across a fork so the next insert opens a transaction" do
      create_connection do |connection|
        connection.execute("CREATE TABLE foo (id INTEGER)")
        connection.insert("INSERT INTO foo (id) VALUES (?)", [1])

        Migrations::ForkManager.fork {}

        connection.insert("INSERT INTO foo (id) VALUES (?)", [2])

        # Row 1 was committed while closing for the fork, but row 2 sits in a
        # freshly opened transaction, so a separate reader can't see it yet.
        reader = described_class.open_database(path: connection.path)
        expect(reader.query_single_splat("SELECT COUNT(*) FROM foo")).to eq(1)
        reader.close
      end
    end

    it "does not reopen the database after a fork when there is no stored path" do
      create_connection do |connection|
        connection.instance_variable_set(:@path, nil)

        Migrations::ForkManager.fork {}

        expect(connection.db).to be_nil
      ensure
        # `@path` is gone and `@db` is nil, so the shared teardown's `close` is a
        # no-op for the handle but still removes the fork hooks.
        connection.instance_variable_set(:@db, nil)
      end
    end
  end
end
