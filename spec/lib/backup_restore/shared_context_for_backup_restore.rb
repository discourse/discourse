# frozen_string_literal: true

shared_context "shared stuff" do
  let!(:logger) do
    Class.new do
      def log(message, ex = nil); end
    end.new
  end

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
    Discourse::Utils.expects(:execute_command).with do |env, *command, **options|
      env["SKIP_POST_DEPLOYMENT_MIGRATIONS"] == "0" &&
        env["SKIP_OPTIMIZE_ICONS"] == "1" &&
        env["DISABLE_TRANSLATION_OVERRIDES"] == "1" &&
        command == ["rake", "db:migrate"] &&
        options[:chdir] == Rails.root
    end.once
  end

  def expect_db_reconnect
    RailsMultisite::ConnectionManagement.expects(:establish_connection).once
  end

  def execute_stubbed_restore(
    stub_readonly_functions: true,
    stub_psql: true,
    stub_migrate: true,
    dump_file_path: "foo.sql"
  )
    expect_table_move
    expect_create_readonly_functions if stub_readonly_functions
    expect_psql if stub_psql
    expect_db_migrate if stub_migrate
    subject.restore(dump_file_path)
  end

  def expect_decompress_and_clean_up_to_work(
    backup_filename:,
    expected_dump_filename: "dump.sql",
    require_metadata_file:,
    require_uploads:,
    expected_upload_paths: nil,
    location: nil
  )
    freeze_time(DateTime.parse("2019-12-24 14:31:48"))

    source_file = File.join(Rails.root, "spec/fixtures/backups", backup_filename)
    target_directory = BackupRestore::LocalBackupStore.base_directory
    target_file = File.join(target_directory, backup_filename)
    FileUtils.copy_file(source_file, target_file)

    Dir.mktmpdir do |root_directory|
      current_db = RailsMultisite::ConnectionManagement.current_db
      file_handler = BackupRestore::BackupFileHandler.new(
        logger, backup_filename, current_db,
        root_tmp_directory: root_directory,
        location: location
      )
      tmp_directory, db_dump_path = file_handler.decompress

      expected_tmp_path = File.join(root_directory, "tmp/restores", current_db, "2019-12-24-143148")
      expect(tmp_directory).to eq(expected_tmp_path)
      expect(db_dump_path).to eq(File.join(expected_tmp_path, expected_dump_filename))

      expect(Dir.exist?(tmp_directory)).to eq(true)
      expect(File.exist?(db_dump_path)).to eq(true)

      expect(File.exist?(File.join(tmp_directory, "meta.json"))).to eq(require_metadata_file)

      if require_uploads
        expected_upload_paths ||= ["uploads/default/original/3X/b/d/bd269860bb508aebcb6f08fe7289d5f117830383.png"]

        expected_upload_paths.each do |upload_path|
          absolute_upload_path = File.join(tmp_directory, upload_path)
          expect(File.exist?(absolute_upload_path)).to eq(true), "expected file #{upload_path} does not exist"
          yield(absolute_upload_path) if block_given?
        end
      else
        expect(Dir.exist?(File.join(tmp_directory, "uploads"))).to eq(false)
      end

      file_handler.clean_up
      expect(Dir.exist?(tmp_directory)).to eq(false)
    end
  ensure
    FileUtils.rm(target_file)

    # We don't want to delete the directory unless it is empty, otherwise this could be annoying
    # when tests run for the "default" database in a development environment.
    FileUtils.rmdir(target_directory) rescue nil
  end
end
