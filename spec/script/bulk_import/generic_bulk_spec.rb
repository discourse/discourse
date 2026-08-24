# frozen_string_literal: true

generic_import_dependencies_available =
  begin
    require "sqlite3"
    require "redcarpet"
    true
  rescue LoadError
    false
  end

if generic_import_dependencies_available
  require_relative "../../../script/bulk_import/generic_bulk"

  RSpec.describe BulkImport::Generic do
    describe ".validate_modes!" do
      it "rejects merge and delta mode together without changing ordinary mode" do
        expect {
          described_class.validate_modes!(merge_import: true, delta_import: true)
        }.to raise_error("MERGE_IMPORT and DELTA_IMPORT cannot be enabled together")

        expect {
          described_class.validate_modes!(merge_import: false, delta_import: false)
        }.not_to raise_error
      end
    end

    describe "mapping selection" do
      fab!(:canonical_user, :user)
      fab!(:other_user, :user)

      it "loads plain 64-bit IDs without consuming merge namespaces" do
        UserCustomField.create!(
          user: canonical_user,
          name: "import_id",
          value: "9223372036854775000",
        )
        UserCustomField.create!(user: other_user, name: "import_id", value: "forum:42")

        mappings = described_class.allocate.plain_import_mappings("user")

        expect(mappings).to eq(9_223_372_036_854_775_000 => canonical_user.id)
      end

      it "keeps the oldest source mapping canonical for a deduplicated user" do
        UserCustomField.create!(
          user: canonical_user,
          name: "import_id",
          value: "10",
          created_at: 2.days.ago,
        )
        UserCustomField.create!(
          user: canonical_user,
          name: "import_id",
          value: "20",
          created_at: 1.day.ago,
        )

        mappings = described_class.allocate.canonical_user_import_mappings

        expect(mappings).to eq(10 => canonical_user.id)
      end
    end

    describe "delta preflight" do
      fab!(:mapped_user) do
        Fabricate(
          :user,
          username: "mapped-user",
          email: "mapped@example.com",
          created_at: 1.year.ago,
        )
      end
      fab!(:conflicting_user) do
        Fabricate(:user, username: "taken-user", email: "taken@example.com")
      end
      fab!(:other_mapped_user, :user)
      fab!(:topic)
      fab!(:other_topic, :topic)
      fab!(:post) { Fabricate(:post, topic: topic) }

      it "reports immutable identity and ownership conflicts" do
        source_db = SQLite3::Database.new(":memory:", results_as_hash: true)
        source_db.execute(<<~SQL)
        CREATE TABLE users (
          id INTEGER PRIMARY KEY,
          username TEXT,
          email TEXT,
          created_at TEXT
        )
      SQL
        source_db.execute(
          "INSERT INTO users (id, username, email, created_at) VALUES (?, ?, ?, ?)",
          [1, conflicting_user.username, conflicting_user.email, Time.zone.now.iso8601],
        )
        importer = described_class.allocate
        importer.instance_variable_set(:@source_db, source_db)
        errors = []

        importer.preflight_users({ 1 => mapped_user.id }, errors)

        expect(errors).to contain_exactly(
          "user 1 changes immutable created_at",
          "user 1 email belongs to Discourse user #{conflicting_user.id}",
        )
        expect(
          importer.instance_variable_get(:@delta_username_conflict_source_ids),
        ).to contain_exactly(1)
      ensure
        source_db&.close
      end

      it "rejects duplicate new emails and usernames within the delta" do
        source_db = SQLite3::Database.new(":memory:", results_as_hash: true)
        source_db.execute(<<~SQL)
        CREATE TABLE users (
          id INTEGER PRIMARY KEY,
          username TEXT,
          email TEXT,
          created_at TEXT
        )
      SQL
        source_db.execute(
          "INSERT INTO users (id, username, email, created_at) VALUES (?, ?, ?, ?)",
          [1, "dupe_user", "dupe@example.com", mapped_user.created_at.iso8601],
        )
        source_db.execute(
          "INSERT INTO users (id, username, email, created_at) VALUES (?, ?, ?, ?)",
          [2, "dupe_user", "dupe@example.com", other_mapped_user.created_at.iso8601],
        )
        importer = described_class.allocate
        importer.instance_variable_set(:@source_db, source_db)
        errors = []

        importer.preflight_users({ 1 => mapped_user.id, 2 => other_mapped_user.id }, errors)

        expect(errors).to contain_exactly(
          "user 2 duplicates email of source user 1",
          "user 2 duplicates username of source user 1",
        )
      ensure
        source_db&.close
      end

      it "accepts an unchanged username whose base import result was suffix-deduplicated" do
        Fabricate(:user, username: "Andrew_S")
        suffixed_user = Fabricate(:user, username: "Andrew_S_1", created_at: 1.year.ago)
        source_db = SQLite3::Database.new(":memory:", results_as_hash: true)
        source_db.execute(<<~SQL)
        CREATE TABLE users (
          id INTEGER PRIMARY KEY,
          username TEXT,
          email TEXT,
          created_at TEXT
        )
      SQL
        source_db.execute(
          "INSERT INTO users (id, username, created_at) VALUES (?, ?, ?)",
          [1, "Andrew_S_", suffixed_user.created_at.iso8601],
        )
        importer = described_class.allocate
        importer.instance_variable_set(:@source_db, source_db)
        errors = []

        importer.preflight_users({ 1 => suffixed_user.id }, errors)

        expect(errors).to be_empty
        expect(importer.instance_variable_get(:@delta_username_conflict_source_ids)).to be_empty
      ensure
        source_db&.close
      end

      it "skips renames to taken usernames unless the import recorded them as unchanged" do
        Fabricate(:user, username: "Andrew_S")
        renamed_user = Fabricate(:user, username: "SomethingElse", created_at: 1.year.ago)
        source_db = SQLite3::Database.new(":memory:", results_as_hash: true)
        source_db.execute(<<~SQL)
        CREATE TABLE users (
          id INTEGER PRIMARY KEY,
          username TEXT,
          email TEXT,
          created_at TEXT
        )
      SQL
        source_db.execute(
          "INSERT INTO users (id, username, created_at) VALUES (?, ?, ?)",
          [1, "Andrew_S_", renamed_user.created_at.iso8601],
        )
        importer = described_class.allocate
        importer.instance_variable_set(:@source_db, source_db)
        errors = []

        importer.preflight_users({ 1 => renamed_user.id }, errors)

        expect(errors).to be_empty
        expect(
          importer.instance_variable_get(:@delta_username_conflict_source_ids),
        ).to contain_exactly(1)

        UserCustomField.create!(user: renamed_user, name: "import_username", value: "Andrew_S_")
        importer = described_class.allocate
        importer.instance_variable_set(:@source_db, source_db)
        errors = []

        importer.preflight_users({ 1 => renamed_user.id }, errors)

        expect(errors).to be_empty
        expect(importer.instance_variable_get(:@delta_username_conflict_source_ids)).to be_empty
      ensure
        source_db&.close
      end

      it "keeps users merged into pre-existing accounts updatable instead of failing" do
        preexisting_user = Fabricate(:user, email: "pre-existing@example.com")
        source_db = SQLite3::Database.new(":memory:", results_as_hash: true)
        source_db.execute(<<~SQL)
        CREATE TABLE users (
          id INTEGER PRIMARY KEY,
          username TEXT,
          email TEXT,
          created_at TEXT
        )
      SQL
        source_db.execute(
          "INSERT INTO users (id, username, email, created_at) VALUES (?, ?, ?, ?)",
          [1, "PreUser", "pre-existing@example.com", 1.year.ago.iso8601],
        )
        importer = described_class.allocate
        importer.instance_variable_set(:@source_db, source_db)
        errors = []

        importer.preflight_users({ 1 => preexisting_user.id }, errors)

        expect(errors).to be_empty
        expect(importer.instance_variable_get(:@delta_preexisting_user_source_ids)).to include(1)

        source_db.execute("UPDATE users SET email = 'unrelated@example.com' WHERE id = 1")
        importer = described_class.allocate
        importer.instance_variable_set(:@source_db, source_db)
        errors = []

        importer.preflight_users({ 1 => preexisting_user.id }, errors)

        expect(errors).to contain_exactly("user 1 changes immutable created_at")

        source_db.execute("UPDATE users SET email = NULL WHERE id = 1")
        importer = described_class.allocate
        importer.instance_variable_set(:@source_db, source_db)
        errors = []

        importer.preflight_users({ 1 => preexisting_user.id }, errors)

        expect(errors).to be_empty
        expect(
          importer.instance_variable_get(:@delta_unverified_user_source_ids),
        ).to contain_exactly(1)
      ensure
        source_db&.close
      end

      it "rejects duplicate group names within the delta" do
        group_a = Fabricate(:group)
        group_b = Fabricate(:group)
        source_db = SQLite3::Database.new(":memory:", results_as_hash: true)
        source_db.execute(<<~SQL)
        CREATE TABLE groups (
          id INTEGER PRIMARY KEY,
          name TEXT,
          existing_id INTEGER
        )
      SQL
        source_db.execute("INSERT INTO groups (id, name) VALUES (1, 'Team Alpha')")
        source_db.execute("INSERT INTO groups (id, name) VALUES (2, 'Team Alpha')")
        importer = described_class.allocate
        importer.instance_variable_set(:@source_db, source_db)
        errors = []

        importer.preflight_groups({ 1 => group_a.id, 2 => group_b.id }, errors)

        expect(errors).to contain_exactly("group 2 duplicates name of source group 1")
      ensure
        source_db&.close
      end

      it "rejects topic archetype changes" do
        source_db = SQLite3::Database.new(":memory:", results_as_hash: true)
        source_db.execute(<<~SQL)
        CREATE TABLE topics (
          id INTEGER PRIMARY KEY,
          created_at TEXT,
          private_message TEXT
        )
      SQL
        source_db.execute(
          "INSERT INTO topics (id, created_at, private_message) VALUES (?, ?, ?)",
          [3_000_000_000, topic.created_at.iso8601, '{"user_ids":[]}'],
        )
        importer = described_class.allocate
        importer.instance_variable_set(:@source_db, source_db)
        errors = []

        importer.preflight_topics({ topics: { 3_000_000_000 => topic.id } }, errors)

        expect(errors).to contain_exactly("topic 3000000000 changes immutable archetype")
      ensure
        source_db&.close
      end

      it "rejects mapped post moves" do
        source_db = SQLite3::Database.new(":memory:", results_as_hash: true)
        source_db.execute(<<~SQL)
        CREATE TABLE posts (
          id INTEGER PRIMARY KEY,
          topic_id INTEGER,
          created_at TEXT,
          post_number INTEGER,
          reply_to_post_id INTEGER
        )
      SQL
        source_db.execute(
          "INSERT INTO posts (id, topic_id, created_at, post_number) VALUES (?, ?, ?, ?)",
          [4_000_000_000, 3_000_000_001, post.created_at.iso8601, post.post_number],
        )
        importer = described_class.allocate
        importer.instance_variable_set(:@source_db, source_db)
        errors = []
        mappings = {
          posts: {
            4_000_000_000 => post.id,
          },
          topics: {
            3_000_000_001 => other_topic.id,
          },
        }

        importer.preflight_posts(mappings, errors)

        expect(errors).to contain_exactly("post 4000000000 changes immutable topic")
      ensure
        source_db&.close
      end
    end
  end

  RSpec.describe BulkImport::Base do
    describe "#update_records" do
      it "updates only supplied, changed values in one transactional batch" do
        db = ActiveRecord::Base.connection_db_config.configuration_hash
        connection = PG.connect(dbname: db[:database], port: db[:port])
        connection.exec(<<~SQL)
        CREATE TEMP TABLE delta_test_records (
          id BIGINT PRIMARY KEY,
          value TEXT,
          preserved TEXT
        )
      SQL
        connection.exec(
          "INSERT INTO delta_test_records VALUES (1, 'old', 'keep'), (2, 'same', 'stay')",
        )
        importer = described_class.allocate
        importer.instance_variable_set(:@raw_connection, connection)
        importer.instance_variable_set(:@encoder, PG::TextEncoder::CopyRow.new)

        result =
          importer.update_records(
            [{ id: 1, value: "new", preserved: nil }, { id: 2, value: "same", preserved: nil }],
            "delta_test_record",
            %i[value preserved],
          )

        records = connection.exec("SELECT id, value, preserved FROM delta_test_records ORDER BY id")
        expect(records.map(&:values)).to eq([%w[1 new keep], %w[2 same stay]])
        expect(result).to include(
          total: 2,
          updated: 1,
          unchanged: 1,
          updated_keys: [1],
          changed_counts: {
            value: 1,
            preserved: 0,
          },
        )

        repeated_result =
          importer.update_records(
            [{ id: 1, value: "new", preserved: nil }, { id: 2, value: "same", preserved: nil }],
            "delta_test_record",
            %i[value preserved],
          )
        expect(repeated_result).to include(
          total: 2,
          updated: 0,
          unchanged: 2,
          updated_keys: [],
          changed_counts: {
            value: 0,
            preserved: 0,
          },
        )
      ensure
        connection&.close
      end

      it "accepts a lazy enumeration of updates" do
        db = ActiveRecord::Base.connection_db_config.configuration_hash
        connection = PG.connect(dbname: db[:database], port: db[:port])
        connection.exec(<<~SQL)
        CREATE TEMP TABLE delta_test_records (
          id BIGINT PRIMARY KEY,
          value TEXT,
          preserved TEXT
        )
      SQL
        connection.exec("INSERT INTO delta_test_records VALUES (1, 'old', 'keep')")
        importer = described_class.allocate
        importer.instance_variable_set(:@raw_connection, connection)
        importer.instance_variable_set(:@encoder, PG::TextEncoder::CopyRow.new)

        result =
          importer.update_records(
            [{ id: 1, value: "new", preserved: nil }].lazy,
            "delta_test_record",
            %i[value preserved],
          )

        records = connection.exec("SELECT id, value, preserved FROM delta_test_records ORDER BY id")
        expect(records.map(&:values)).to eq([%w[1 new keep]])
        expect(result).to include(
          total: 1,
          updated: 1,
          unchanged: 0,
          updated_keys: [1],
          changed_counts: {
            value: 1,
            preserved: 0,
          },
        )
      ensure
        connection&.close
      end
    end
  end
else
  RSpec.describe "generic bulk import specs" do
    it "requires the generic_import bundle group" do
      skip "Run with BUNDLE_WITH=generic_import"
    end
  end
end
