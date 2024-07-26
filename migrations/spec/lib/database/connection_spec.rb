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

  describe "#reconnect" do
    it "reopens the correct database" do
      create_connection do |connection|
        path = connection.path
        db = connection.db
        db.execute("CREATE TABLE foo (id INTEGER)")

        connection.close
        expect(db).to be_closed

        connection.reconnect
        db = connection.db

        expect(db).not_to be_closed
        expect(connection.path).to eq(path)
        expect(db.tables).to contain_exactly("foo")
      end
    end
  end

  describe "#copy_from" do
    before do
      @storage_path = Dir.mktmpdir
      @main_db_path = File.join(@storage_path, "main.db")
      @db1_path = File.join(@storage_path, "part1.db")
      @db2_path = File.join(@storage_path, "part2.db")
      @db3_path = File.join(@storage_path, "part3.db")

      @main_db = create_db(@main_db_path)
      @db1 = create_db(@db1_path)
      @db2 = create_db(@db2_path)
      @db3 = create_db(@db3_path)
    end

    after do
      [@main_db, @db1, @db2, @db3].each { |db| db.close }
      FileUtils.remove_dir(@storage_path, force: true)
    end

    def create_db(db_path)
      migrations_path = File.join(Migrations.root_path, "spec", "fixtures", "schema", "copy")
      Migrations::Database.migrate(db_path, migrations_path:)
      described_class.open_database(path: db_path)
    end

    it "commits an active transaction" do
      Migrations::Database.connect(@main_db_path) do |main_connection|
        main_connection.insert("INSERT INTO users (id, username) VALUES (?, ?)", [1, "sam"])

        expect(@main_db.query_single_splat("SELECT COUNT(*) FROM users")).to eq(0)
        main_connection.copy_from([@db1_path, @db2_path, @db3_path])
        expect(@main_db.query_single_splat("SELECT COUNT(*) FROM users")).to eq(1)
      end
    end

    it "copies data from multiple DBs into the current DB" do
      @main_db.execute("INSERT INTO uploads (id, url) VALUES (?, ?)", 1, "url1")

      @db1.execute("INSERT INTO users (id, username) VALUES (?, ?)", 1, "user1")
      @db1.execute("INSERT INTO users (id, username) VALUES (?, ?)", 2, "user2")
      @db1.execute("INSERT INTO uploads (id, url) VALUES (?, ?)", 2, "url2")

      @db2.execute("INSERT INTO users (id, username) VALUES (?, ?)", 3, "user3")
      @db2.execute("INSERT INTO uploads (id, url) VALUES (?, ?)", 3, "url3")

      @db2.execute("INSERT INTO users (id, username) VALUES (?, ?)", 4, "user4")
      @db2.execute("INSERT INTO uploads (id, url) VALUES (?, ?)", 4, "url4")

      Migrations::Database.connect(@main_db_path) do |main_connection|
        main_connection.copy_from([@db1_path, @db2_path, @db3_path])
      end

      expect(@main_db.query_splat("SELECT username FROM users")).to contain_exactly(
        "user1",
        "user2",
        "user3",
        "user4",
      )
      expect(@main_db.query_splat("SELECT url FROM uploads")).to contain_exactly(
        "url1",
        "url2",
        "url3",
        "url4",
      )
    end

    context "with duplicate data" do
      it "raises an error when copying data violates a unique constraint" do
        @db1.execute("INSERT INTO users (id, username) VALUES (?, ?)", 1, "user1")
        @db2.execute("INSERT INTO users (id, username) VALUES (?, ?)", 1, "user1")

        Migrations::Database.connect(@main_db_path) do |main_connection|
          expect { main_connection.copy_from([@db1_path, @db2_path]) }.to raise_error(
            Extralite::Error,
            "UNIQUE constraint failed: users.id",
          )
        end
      end

      it "ignores duplicate records when `insert_actions` are configured" do
        @db1.execute("INSERT INTO users (id, username) VALUES (?, ?)", 1, "user1")
        @db2.execute("INSERT INTO users (id, username) VALUES (?, ?)", 1, "user1")

        insert_actions = { "users" => "OR IGNORE" }

        Migrations::Database.connect(@main_db_path) do |main_connection|
          main_connection.copy_from([@db1_path, @db2_path], insert_actions:)
        end

        expect(@main_db.query_splat("SELECT username FROM users")).to contain_exactly("user1")
      end

      it "replaces duplicate records when `insert_actions` are configured" do
        @main_db.execute("INSERT INTO config (name, value) VALUES (?, ?)", "foo", "old value")
        @db1.execute("INSERT INTO config (name, value) VALUES (?, ?)", "foo", "db1 value")
        @db2.execute("INSERT INTO config (name, value) VALUES (?, ?)", "foo", "db2 value")

        insert_actions = { "config" => "OR REPLACE" }

        Migrations::Database.connect(@main_db_path) do |main_connection|
          main_connection.copy_from([@db1_path, @db2_path], insert_actions:)
        end

        expect(
          @main_db.query_splat("SELECT value FROM config WHERE name = 'foo'"),
        ).to contain_exactly("db2 value")
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
