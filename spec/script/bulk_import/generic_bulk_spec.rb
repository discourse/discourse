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

      it "keeps base-import fallback usernames untouched when unicode support is enabled later" do
        SiteSetting.unicode_usernames = true
        fallback_user = Fabricate(:user, username: "Anonymous_339dfc", created_at: 1.year.ago)
        UserCustomField.create!(user: fallback_user, name: "import_username", value: "千风")
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
          [1, "千风", fallback_user.created_at.iso8601],
        )
        importer = described_class.allocate
        importer.instance_variable_set(:@source_db, source_db)
        errors = []

        importer.preflight_users({ 1 => fallback_user.id }, errors)

        expect(errors).to be_empty
        expect(importer.instance_variable_get(:@delta_username_conflict_source_ids)).to be_empty
        expect(
          importer.delta_username_unchanged?(
            { "username" => "千风" },
            fallback_user.id,
            fallback_user.username_lower,
          ),
        ).to eq(true)
      ensure
        source_db&.close
      end

      it "keeps a destination username the source still carries verbatim under a stricter sanitizer" do
        kept_user = Fabricate(:user, username: "userjs")
        kept_user.update_columns(username: "user.js", username_lower: "user.js")
        importer = described_class.allocate

        expect(importer.fix_name("user.js")).to eq("user")
        expect(
          importer.delta_username_unchanged?({ "username" => "user.js" }, kept_user.id, "user.js"),
        ).to eq(true)
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

      it "rejects duplicate group names differing only in unicode case within the delta" do
        SiteSetting.unicode_usernames = true
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
        source_db.execute("INSERT INTO groups (id, name) VALUES (1, 'Équipe')")
        source_db.execute("INSERT INTO groups (id, name) VALUES (2, 'équipe')")
        importer = described_class.allocate
        importer.instance_variable_set(:@source_db, source_db)
        errors = []

        importer.preflight_groups({ 1 => group_a.id, 2 => group_b.id }, errors)

        expect(errors).to contain_exactly("group 2 duplicates name of source group 1")
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

    describe "#configure_unicode_usernames!" do
      def build_source_db(usernames: [], group_names: [], site_settings: {})
        db = SQLite3::Database.new(":memory:", results_as_hash: true)
        db.execute(
          "CREATE TABLE users (id INTEGER PRIMARY KEY, username TEXT, original_username TEXT)",
        )
        db.execute("CREATE TABLE groups (id INTEGER PRIMARY KEY, name TEXT)")
        db.execute("CREATE TABLE site_settings (name TEXT, value TEXT, action TEXT)")
        usernames.each_with_index do |username, index|
          db.execute("INSERT INTO users (id, username) VALUES (?, ?)", [index + 1, username])
        end
        group_names.each_with_index do |name, index|
          db.execute("INSERT INTO groups (id, name) VALUES (?, ?)", [index + 1, name])
        end
        site_settings.each do |name, value|
          db.execute(
            "INSERT INTO site_settings (name, value, action) VALUES (?, ?, 'update')",
            [name.to_s, value],
          )
        end
        db
      end

      def build_importer(source_db)
        importer = described_class.allocate
        importer.instance_variable_set(:@source_db, source_db)
        importer.instance_variable_set(
          :@import_issue_log_path,
          File.join(Dir.mktmpdir, "issues.log"),
        )
        importer
      end

      it "enables unicode_usernames when the source contains non-ASCII usernames" do
        source_db = build_source_db(usernames: %w[alice 千风])
        importer = build_importer(source_db)

        importer.configure_unicode_usernames!

        expect(SiteSetting.unicode_usernames).to eq(true)
        expect(importer.instance_variable_get(:@import_issue_counts)).to eq(
          "unicode_usernames auto-enabled" => 1,
        )
      ensure
        source_db&.close
      end

      it "enables unicode_usernames when only group names contain non-ASCII characters" do
        source_db = build_source_db(usernames: %w[alice], group_names: ["中文组"])
        importer = build_importer(source_db)

        importer.configure_unicode_usernames!

        expect(SiteSetting.unicode_usernames).to eq(true)
      ensure
        source_db&.close
      end

      it "keeps unicode_usernames off for ASCII-only sources" do
        source_db = build_source_db(usernames: %w[alice bob], group_names: %w[team])
        importer = build_importer(source_db)

        importer.configure_unicode_usernames!

        expect(SiteSetting.unicode_usernames).to eq(false)
        expect(importer.instance_variable_get(:@import_issue_counts)).to be_nil
      ensure
        source_db&.close
      end

      it "lets an explicit source setting disable the automatic detection" do
        source_db = build_source_db(usernames: %w[千风], site_settings: { unicode_usernames: "f" })
        importer = build_importer(source_db)

        importer.configure_unicode_usernames!

        expect(SiteSetting.unicode_usernames).to eq(false)
      ensure
        source_db&.close
      end

      it "applies an explicit source setting and allowlist for ASCII-only sources" do
        source_db =
          build_source_db(
            usernames: %w[alice],
            site_settings: {
              unicode_usernames: "t",
              allowed_unicode_username_characters: '\p{Han}',
            },
          )
        importer = build_importer(source_db)

        importer.configure_unicode_usernames!

        expect(SiteSetting.unicode_usernames).to eq(true)
        expect(SiteSetting.allowed_unicode_username_characters).to eq('\p{Han}')
      ensure
        source_db&.close
      end

      it "raises a clear error when external system avatars are unavailable" do
        SiteSetting.external_system_avatars_url = ""
        source_db = build_source_db(usernames: %w[千风])
        importer = build_importer(source_db)

        expect { importer.configure_unicode_usernames! }.to raise_error(
          /external_system_avatars_url/,
        )
        expect(SiteSetting.unicode_usernames).to eq(false)
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

    describe "#fix_name" do
      it "transliterates names to ASCII when unicode usernames are disabled" do
        importer = described_class.allocate

        expect(importer.fix_name("José")).to eq("Jose")
        expect(importer.fix_name("千风")).to be_nil
      end

      it "keeps and NFC-normalizes unicode names when unicode usernames are enabled" do
        SiteSetting.unicode_usernames = true
        importer = described_class.allocate

        expect(importer.fix_name("千风")).to eq("千风")
        expect(importer.fix_name("José")).to eq("José")
        expect(importer.fix_name("风" * 61)).to eq("风" * 60)
        expect(importer.fix_name("😀😀")).to be_nil
      end

      it "respects the unicode username character allowlist" do
        SiteSetting.unicode_usernames = true
        SiteSetting.allowed_unicode_username_characters = '\p{Han}'
        importer = described_class.allocate

        expect(importer.fix_name("千风")).to eq("千风")
        expect(importer.fix_name("Кир")).to be_nil
      end
    end

    describe "#process_user" do
      def build_user_importer
        importer = described_class.allocate
        importer.instance_variable_set(:@usernames_lower, Set.new)
        importer.instance_variable_set(:@last_user_id, 0)
        importer.instance_variable_set(
          :@import_issue_log_path,
          File.join(Dir.mktmpdir, "issues.log"),
        )
        %i[
          users
          emails
          external_ids
          imported_usernames
          mapped_usernames
          user_ids_by_username_lower
          usernames_by_id
          user_full_names_by_id
        ].each { |name| importer.instance_variable_set(:"@#{name}", {}) }
        importer
      end

      it "imports unicode usernames with a normalized username_lower" do
        SiteSetting.unicode_usernames = true
        importer = build_user_importer

        user = importer.process_user(imported_id: 1, username: "千风")

        expect(user[:username]).to eq("千风")
        expect(user[:username_lower]).to eq(User.normalize_username("千风"))
      end

      it "falls back to a random username and logs an issue when sanitization strips everything" do
        importer = build_user_importer

        user = importer.process_user(imported_id: 1, username: "千风")

        expect(user[:username]).to start_with("Anonymous_")
        expect(importer.instance_variable_get(:@import_issue_counts)).to eq(
          "username sanitized to blank" => 1,
        )
        expect(importer.instance_variable_get(:@mapped_usernames)).to eq("千风" => user[:username])
      end

      it "keeps deduplicated unicode usernames within the 60 character limit" do
        SiteSetting.unicode_usernames = true
        importer = build_user_importer
        long_name = "风" * 60
        importer.instance_variable_get(:@usernames_lower) << User.normalize_username(long_name)

        user = importer.process_user(imported_id: 1, username: long_name)

        expect(user[:username]).to eq("#{"风" * 58}_1")
      end
    end

    describe "#pre_cook" do
      it "links unicode mentions to imported users and groups" do
        importer = described_class.allocate
        importer.instance_variable_set(
          :@markdown,
          Redcarpet::Markdown.new(
            Redcarpet::Render::HTML.new(hard_wrap: true),
            no_intra_emphasis: true,
            fenced_code_blocks: true,
            autolink: true,
          ),
        )
        importer.instance_variable_set(:@mapped_usernames, { "千风" => "Anonymous_abc" })
        importer.instance_variable_set(
          :@usernames_lower,
          Set.new(["anonymous_abc", User.normalize_username("张伟")]),
        )
        importer.instance_variable_set(
          :@group_names_lower,
          Set.new([User.normalize_username("中文组")]),
        )

        cooked = importer.pre_cook("Hello @千风 and @张伟 and @中文组")

        expect(cooked).to include(
          %{<a class="mention" href="/u/anonymous_abc">@Anonymous_abc</a>},
          %{<a class="mention" href="/u/张伟">@张伟</a>},
          %{<a class="mention-group" href="/groups/中文组">@中文组</a>},
        )
      end
    end

    describe "#log_import_issue" do
      it "aggregates counts per category and streams details to the log file" do
        importer = described_class.allocate
        log_path = File.join(Dir.mktmpdir, "issues.log")
        importer.instance_variable_set(:@import_issue_log_path, log_path)

        importer.log_import_issue("unresolved user mention", "[mention|abc] (content 1)")
        importer.log_import_issue("unresolved user mention", "[mention|def] (content 2)")
        importer.log_import_issue("post skipped (raw contains null bytes)", "post 3")

        expect(File.readlines(log_path, chomp: true)).to eq(
          [
            "[unresolved user mention] [mention|abc] (content 1)",
            "[unresolved user mention] [mention|def] (content 2)",
            "[post skipped (raw contains null bytes)] post 3",
          ],
        )
        expect { importer.report_import_issues }.to output(
          [
            "",
            "Import issues (details in #{log_path}):",
            "  unresolved user mention: 2",
            "  post skipped (raw contains null bytes): 1",
            "",
          ].join("\n"),
        ).to_stdout
      end

      it "reports nothing when no issues were logged" do
        expect { described_class.allocate.report_import_issues }.not_to output.to_stdout
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
