# frozen_string_literal: true

require_relative "shared_context_for_backup_restore"

RSpec.describe BackupRestore::DatabaseRestorer do
  subject(:restorer) { BackupRestore::DatabaseRestorer.new(logger, current_db) }

  include_context "with shared backup restore context"

  let(:current_db) { RailsMultisite::ConnectionManagement.current_db }

  describe "#restore" do
    it "executes everything in the correct order" do
      restore = sequence("restore")
      expect_table_move.in_sequence(restore)
      expect_create_readonly_functions.in_sequence(restore)
      expect_psql(stub_thread: true).in_sequence(restore)
      expect_db_migrate.in_sequence(restore)
      expect_db_reconnect.in_sequence(restore)

      restorer.restore("foo.sql")
    end

    it "stores the date of the last restore" do
      date_string = "2020-01-10T17:38:27Z"
      freeze_time(Time.parse(date_string))
      execute_stubbed_restore

      expect(BackupMetadata.value_for(BackupMetadata::LAST_RESTORE_DATE)).to eq(date_string)
    end

    context "with real psql" do
      after do
        psql = BackupRestore::DatabaseRestorer.psql_command
        system("#{psql} -c 'DROP TABLE IF EXISTS foo'", %i[out err] => File::NULL)
      end

      def restore(filename, stub_migrate: true)
        path = File.join(Rails.root, "spec/fixtures/db/restore", filename)
        execute_stubbed_restore(stub_psql: false, stub_migrate: stub_migrate, dump_file_path: path)
      end

      def expect_restore_to_work(filename)
        restore(filename, stub_migrate: true)
        expect(ActiveRecord::Base.connection.table_exists?("foo")).to eq(true)
      end

      it "restores from PostgreSQL 9.3" do
        # this covers the defaults of Discourse v1.0 up to v1.5
        expect_restore_to_work("postgresql_9.3.11.sql")
      end

      it "restores from PostgreSQL 9.5.5" do
        # it uses a slightly different header than later 9.5.x versions
        expect_restore_to_work("postgresql_9.5.5.sql")
      end

      it "restores from PostgreSQL 9.5" do
        # this covers the defaults of Discourse v1.6 up to v1.9
        expect_restore_to_work("postgresql_9.5.10.sql")
      end

      it "restores from PostgreSQL 10" do
        # this covers the defaults of Discourse v1.7 up to v2.4
        expect_restore_to_work("postgresql_10.11.sql")
      end

      it "restores from PostgreSQL 11" do
        expect_restore_to_work("postgresql_11.6.sql")
      end

      it "restores from PostgreSQL 12" do
        expect_restore_to_work("postgresql_12.1.sql")
      end

      it "detects error during restore" do
        expect { restore("error.sql", stub_migrate: false) }.to raise_error(
          BackupRestore::DatabaseRestoreError,
        )
      end
    end

    describe "rewrites database dump" do
      let(:logger) do
        Class
          .new do
            attr_reader :log_messages

            def initialize
              @log_messages = []
            end

            def log(message, ex = nil)
              @log_messages << message if message
            end
          end
          .new
      end

      def restore_and_log_output(filename)
        path = File.join(Rails.root, "spec/fixtures/db/restore", filename)
        BackupRestore::DatabaseRestorer.stubs(:psql_command).returns("cat")
        execute_stubbed_restore(stub_psql: false, dump_file_path: path)
        logger.log_messages.join("\n")
      end

      it "replaces `EXECUTE FUNCTION` when restoring on PostgreSQL < 11" do
        BackupRestore.stubs(:postgresql_major_version).returns(10)
        log = restore_and_log_output("trigger.sql")

        expect(log).not_to be_blank
        expect(log).not_to match(/CREATE SCHEMA public/)
        expect(log).not_to match(/EXECUTE FUNCTION/)
        expect(log).to match(
          /^CREATE TRIGGER foo_topic_id_readonly .+? EXECUTE PROCEDURE discourse_functions.raise_foo_topic_id_readonly/,
        )
        expect(log).to match(
          /^CREATE TRIGGER foo_user_id_readonly .+? EXECUTE PROCEDURE discourse_functions.raise_foo_user_id_readonly/,
        )
      end

      it "does not replace `EXECUTE FUNCTION` when restoring on PostgreSQL >= 11" do
        BackupRestore.stubs(:postgresql_major_version).returns(11)
        log = restore_and_log_output("trigger.sql")

        expect(log).not_to be_blank
        expect(log).not_to match(/CREATE SCHEMA public/)
        expect(log).not_to match(/EXECUTE PROCEDURE/)
        expect(log).to match(
          /^CREATE TRIGGER foo_topic_id_readonly .+? EXECUTE FUNCTION discourse_functions.raise_foo_topic_id_readonly/,
        )
        expect(log).to match(
          /^CREATE TRIGGER foo_user_id_readonly .+? EXECUTE FUNCTION discourse_functions.raise_foo_user_id_readonly/,
        )
      end
    end

    describe "database connection" do
      it "it is not erroring for non-multisite" do
        expect { execute_stubbed_restore }.not_to raise_error
      end
    end
  end

  describe "#rollback" do
    it "moves tables back when tables were moved" do
      BackupRestore.stubs(:can_rollback?).returns(true)
      BackupRestore.expects(:move_tables_between_schemas).with("backup", "public").never
      restorer.rollback

      execute_stubbed_restore

      BackupRestore.expects(:move_tables_between_schemas).with("backup", "public").once
      restorer.rollback
    end
  end

  describe "readonly functions" do
    before do
      BackupRestore::DatabaseRestorer.stubs(:all_migration_files).returns(
        Dir[Rails.root.join("spec/fixtures/db/post_migrate/drop_column/**/*.rb")],
      )
    end

    it "doesn't try to drop function when no functions have been created" do
      Migration::BaseDropper.expects(:drop_readonly_function).never
      restorer.clean_up
    end

    it "creates and drops all functions when none exist" do
      Migration::BaseDropper.expects(:create_readonly_function).with(:posts, :via_email)
      Migration::BaseDropper.expects(:create_readonly_function).with(:posts, :raw_email)
      execute_stubbed_restore(stub_readonly_functions: false)

      Migration::BaseDropper.expects(:drop_readonly_function).with(:posts, :via_email)
      Migration::BaseDropper.expects(:drop_readonly_function).with(:posts, :raw_email)
      restorer.clean_up
    end

    it "creates and drops only missing functions during restore" do
      Migration::BaseDropper.stubs(:existing_discourse_function_names).returns(
        %w[raise_email_logs_readonly raise_posts_raw_email_readonly],
      )

      Migration::BaseDropper.expects(:create_readonly_function).with(:posts, :via_email)
      execute_stubbed_restore(stub_readonly_functions: false)

      Migration::BaseDropper.expects(:drop_readonly_function).with(:posts, :via_email)
      restorer.clean_up
    end
  end

  describe ".drop_backup_schema" do
    context "when no backup schema exists" do
      it "doesn't do anything" do
        ActiveRecord::Base.connection.expects(:schema_exists?).with("backup").returns(false)
        ActiveRecord::Base.connection.expects(:drop_schema).never

        described_class.drop_backup_schema
      end
    end

    context "when a backup schema exists" do
      before { ActiveRecord::Base.connection.expects(:schema_exists?).with("backup").returns(true) }

      it "drops the schema when the last restore was long ago" do
        ActiveRecord::Base.connection.expects(:drop_schema).with("backup")
        BackupMetadata.update_last_restore_date(8.days.ago)

        described_class.drop_backup_schema
      end

      it "doesn't drop the schema when the last restore was recently" do
        ActiveRecord::Base.connection.expects(:drop_schema).with("backup").never
        BackupMetadata.update_last_restore_date(6.days.ago)

        described_class.drop_backup_schema
      end

      it "stores the current date when there is no record of the last restore" do
        ActiveRecord::Base.connection.expects(:drop_schema).with("backup").never

        date_string = "2020-01-08T17:38:27Z"
        freeze_time(Time.parse(date_string))

        described_class.drop_backup_schema
        expect(BackupMetadata.value_for(BackupMetadata::LAST_RESTORE_DATE)).to eq(date_string)
      end
    end
  end
end
