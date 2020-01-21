# frozen_string_literal: true

require 'rails_helper'
require_relative 'shared_context_for_backup_restore'

describe BackupRestore::DatabaseRestorer do
  include_context "shared stuff"

  let(:current_db) { RailsMultisite::ConnectionManagement.current_db }
  subject { BackupRestore::DatabaseRestorer.new(logger, current_db) }

  def expect_create_readonly_functions
    Migration::BaseDropper.expects(:create_readonly_function).at_least_once
  end

  def expect_table_move
    BackupRestore.expects(:move_tables_between_schemas).with("public", "backup").once
  end

  def expect_psql(output_lines: ["output from psql"], exit_status: 0, stub_thread: false)
    status = mock("psql status")
    status.expects(:exitstatus).returns(exit_status).once
    Process.expects(:last_status).returns(status).once

    if stub_thread
      thread = mock("thread")
      thread.stubs(:join)
      Thread.stubs(:new).returns(thread)
    end

    output_lines << nil
    psql_io = mock("psql")
    psql_io.expects(:readline).returns(*output_lines).times(output_lines.size)
    IO.expects(:popen).yields(psql_io).once
  end

  def expect_db_migrate
    Discourse::Utils.expects(:execute_command).with do |env, command, options|
      env["SKIP_POST_DEPLOYMENT_MIGRATIONS"] == "0" &&
        command == "rake db:migrate" &&
        options[:chdir] == Rails.root
    end.once
  end

  def expect_db_reconnect
    RailsMultisite::ConnectionManagement.expects(:establish_connection).once
  end

  def execute_stubbed_restore(stub_readonly_functions: true, stub_psql: true, stub_migrate: true,
                              dump_file_path: "foo.sql")
    expect_table_move
    expect_create_readonly_functions if stub_readonly_functions
    expect_psql if stub_psql
    expect_db_migrate if stub_migrate
    subject.restore(dump_file_path)
  end

  describe "#restore" do
    it "executes everything in the correct order" do
      restore = sequence("restore")
      expect_table_move.in_sequence(restore)
      expect_create_readonly_functions.in_sequence(restore)
      expect_psql(stub_thread: true).in_sequence(restore)
      expect_db_migrate.in_sequence(restore)
      expect_db_reconnect.in_sequence(restore)

      subject.restore("foo.sql")
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
        system("#{psql} -c 'DROP TABLE IF EXISTS foo'", [:out, :err] => File::NULL)
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
        expect { restore("error.sql", stub_migrate: false) }
          .to raise_error(BackupRestore::DatabaseRestoreError)
      end
    end

    context "database connection" do
      it 'reconnects to the correct database', type: :multisite do
        RailsMultisite::ConnectionManagement.establish_connection(db: 'second')
        execute_stubbed_restore
        expect(RailsMultisite::ConnectionManagement.current_db).to eq('second')
      end

      it 'it is not erroring for non-multisite' do
        expect { execute_stubbed_restore }.not_to raise_error
      end
    end
  end

  describe "#rollback" do
    it "moves tables back when tables were moved" do
      BackupRestore.stubs(:can_rollback?).returns(true)
      BackupRestore.expects(:move_tables_between_schemas).with("backup", "public").never
      subject.rollback

      execute_stubbed_restore

      BackupRestore.expects(:move_tables_between_schemas).with("backup", "public").once
      subject.rollback
    end
  end

  context "readonly functions" do
    before do
      Migration::SafeMigrate.stubs(:post_migration_path).returns("spec/fixtures/db/post_migrate")
    end

    it "doesn't try to drop function when no functions have been created" do
      Migration::BaseDropper.expects(:drop_readonly_function).never
      subject.clean_up
    end

    it "creates and drops all functions when none exist" do
      Migration::BaseDropper.expects(:create_readonly_function).with(:email_logs, nil)
      Migration::BaseDropper.expects(:create_readonly_function).with(:posts, :via_email)
      Migration::BaseDropper.expects(:create_readonly_function).with(:posts, :raw_email)
      execute_stubbed_restore(stub_readonly_functions: false)

      Migration::BaseDropper.expects(:drop_readonly_function).with(:email_logs, nil)
      Migration::BaseDropper.expects(:drop_readonly_function).with(:posts, :via_email)
      Migration::BaseDropper.expects(:drop_readonly_function).with(:posts, :raw_email)
      subject.clean_up
    end

    it "creates and drops only missing functions during restore" do
      Migration::BaseDropper.stubs(:existing_discourse_function_names)
        .returns(%w(raise_email_logs_readonly raise_posts_raw_email_readonly))

      Migration::BaseDropper.expects(:create_readonly_function).with(:posts, :via_email)
      execute_stubbed_restore(stub_readonly_functions: false)

      Migration::BaseDropper.expects(:drop_readonly_function).with(:posts, :via_email)
      subject.clean_up
    end
  end

  describe ".drop_backup_schema" do
    subject { BackupRestore::DatabaseRestorer }

    context "when no backup schema exists" do
      it "doesn't do anything" do
        ActiveRecord::Base.connection.expects(:schema_exists?).with("backup").returns(false)
        ActiveRecord::Base.connection.expects(:drop_schema).never

        subject.drop_backup_schema
      end
    end

    context "when a backup schema exists" do
      before do
        ActiveRecord::Base.connection.expects(:schema_exists?).with("backup").returns(true)
      end

      it "drops the schema when the last restore was long ago" do
        ActiveRecord::Base.connection.expects(:drop_schema).with("backup")

        freeze_time(8.days.ago) do
          subject.update_last_restore_date
        end

        subject.drop_backup_schema
      end

      it "doesn't drop the schema when the last restore was recently" do
        ActiveRecord::Base.connection.expects(:drop_schema).with("backup").never

        freeze_time(6.days.ago) do
          subject.update_last_restore_date
        end

        subject.drop_backup_schema
      end

      it "stores the current date when there is no record of the last restore" do
        ActiveRecord::Base.connection.expects(:drop_schema).with("backup").never

        date_string = "2020-01-08T17:38:27Z"
        freeze_time(Time.parse(date_string))

        subject.drop_backup_schema
        expect(BackupMetadata.value_for(BackupMetadata::LAST_RESTORE_DATE)).to eq(date_string)
      end
    end
  end
end
