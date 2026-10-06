# frozen_string_literal: true

require_relative "shared_context_for_backup_restore"

RSpec.describe BackupRestore do
  include_context "with shared backup restore context"

  let(:current_db) { RailsMultisite::ConnectionManagement.current_db }
  let(:restorer) { BackupRestore::DatabaseRestorer.new(logger, current_db) }

  before do
    config = BackupRestore.database_configuration
    connection_options = {
      host: config.host,
      port: config.port,
      user: config.username,
      password: config.password,
      dbname: config.database,
    }
    @admin_connection = PG.connect(connection_options)
    @database = "discourse_backup_test_#{SecureRandom.hex(6)}"
    @admin_connection.exec("CREATE DATABASE #{@database}")
    @connection = PG.connect(connection_options.merge(dbname: @database))
    @connection.exec("SET client_min_messages = warning")
    BackupRestore.stubs(:database_configuration).returns(
      config.dup.tap { |c| c.database = @database },
    )

    @directory = Dir.mktmpdir("backup ' $HOME ; ")
    @dump_directory = File.join(@directory, BackupRestore::DUMP_DIRECTORY)
    @creator = BackupRestore::Creator.new(nil, with_uploads: false)
    @creator.instance_variable_set(:@dump_filename, @dump_directory)
    @creator.instance_variable_set(:@tmp_directory, @directory)

    @connection.exec(<<~SQL)
      CREATE TABLE parents (id serial PRIMARY KEY, name text NOT NULL);
      CREATE TABLE children (id serial PRIMARY KEY, parent_id integer REFERENCES parents(id), body text);
      CREATE INDEX children_body_idx ON children(body);
      INSERT INTO parents(name) VALUES ('first'), ('second');
      INSERT INTO children(parent_id, body) VALUES (1, 'one'), (2, 'two');
      CREATE TABLE nested_hot_post_scores (id integer);
      INSERT INTO nested_hot_post_scores VALUES (1);
    SQL
  end

  after do
    @connection&.close
    @admin_connection&.exec("DROP DATABASE IF EXISTS #{@database}") if @database
    @admin_connection&.close
    FileUtils.rm_rf(@directory) if @directory
  end

  def dump_database(concurrency: 2)
    GlobalSetting.stubs(:backup_database_concurrency).returns(concurrency)
    @creator.send(:dump_public_schema)
  end

  def empty_database
    @connection.exec("DROP TABLE children, parents, nested_hot_post_scores")
  end

  [1, 2].each do |concurrency|
    it "round trips data, indexes, constraints and sequences with #{concurrency} workers" do
      dump_database(concurrency: concurrency)
      empty_database
      GlobalSetting.stubs(:backup_database_concurrency).returns(concurrency)
      restorer.instance_variable_set(:@db_dump_path, @dump_directory)

      restorer.send(:restore_dump)

      expect(@connection.exec("SELECT name FROM parents ORDER BY id").column_values(0)).to eq(
        %w[first second],
      )
      expect(@connection.exec("SELECT body FROM children ORDER BY id").column_values(0)).to eq(
        %w[one two],
      )
      expect(@connection.exec("SELECT * FROM nested_hot_post_scores").ntuples).to eq(0)
      expect(@connection.exec("SELECT to_regclass('children_body_idx')").getvalue(0, 0)).to eq(
        "children_body_idx",
      )
      expect(
        @connection.exec("INSERT INTO parents(name) VALUES ('third') RETURNING id").getvalue(0, 0),
      ).to eq("3")
      expect { @connection.exec("INSERT INTO children(parent_id) VALUES (999)") }.to raise_error(
        PG::ForeignKeyViolation,
      )
    end
  end

  [false, true].each do |with_uploads|
    it "packages and extracts a directory dump with uploads set to #{with_uploads}" do
      SiteSetting.enable_s3_uploads = false
      @creator.instance_variable_set(:@with_uploads, with_uploads)
      public_directory = Pathname.new(File.join(@directory, "public"))
      Rails.stubs(:public_path).returns(public_directory)
      upload_path = File.join(Discourse.store.upload_path, "original", "test.txt")
      FileUtils.mkdir_p(public_directory.join(File.dirname(upload_path)))
      File.write(public_directory.join(upload_path), "test upload")

      Dir.mktmpdir do |archive_directory|
        @creator.instance_variable_set(:@archive_basename, File.join(archive_directory, "backup"))
        @creator.expects(:add_local_uploads_to_archive).never unless with_uploads
        @creator.expects(:add_remote_uploads_to_archive).never
        @creator.send(:create_archive)

        BackupRestore::LocalBackupStore.stubs(:base_directory).returns(archive_directory)
        handler =
          BackupRestore::BackupFileHandler.new(
            logger,
            "backup.tar",
            current_db,
            root_tmp_directory: archive_directory,
          )

        _filename, tmp_directory, dump_path = handler.decompress
        expect(File.file?(File.join(dump_path, "toc.dat"))).to eq(true)
        expect(File.exist?(File.join(tmp_directory, upload_path))).to eq(with_uploads)
        if with_uploads
          expect(File.read(File.join(tmp_directory, upload_path))).to eq("test upload")
        end

        empty_database
        restorer.instance_variable_set(:@db_dump_path, dump_path)
        restorer.send(:restore_dump)
        expect(@connection.exec("SELECT count(*) FROM children").getvalue(0, 0)).to eq("2")

        handler.clean_up
        expect(Dir.exist?(tmp_directory)).to eq(false)
      end
    end
  end

  it "does not restore data if schema creation fails" do
    dump_database
    restorer.instance_variable_set(:@db_dump_path, @dump_directory)
    restorer.expects(:pg_restore_command).never

    expect { restorer.send(:restore_dump) }.to raise_error(
      BackupRestore::DatabaseRestoreError,
      /psql failed/,
    )
  end

  it "rejects an unreadable archive before moving tables" do
    FileUtils.mkdir_p(@dump_directory)
    File.write(File.join(@dump_directory, "toc.dat"), "invalid archive")
    BackupRestore.expects(:move_tables_between_schemas).never

    expect { restorer.restore(@dump_directory) }.to raise_error(
      RuntimeError,
      /This database dump cannot be read/,
    )
    restorer.rollback
    expect(@connection.exec("SELECT count(*) FROM children").getvalue(0, 0)).to eq("2")
  end

  it "stops on a failed parallel restore and can roll back the original tables" do
    dump_database
    # Simulate an older backup, so the pre-restore database contains additional data.
    @connection.exec("INSERT INTO parents(name) VALUES ('keep on rollback')")
    @connection.exec(
      BackupRestore.move_tables_between_schemas_sql("public", "backup", @connection.user),
    )
    restorer.instance_variable_set(:@db_was_changed, true)
    restorer.instance_variable_set(:@db_dump_path, @dump_directory)
    GlobalSetting.stubs(:backup_database_concurrency).returns(2)

    # Removing table data forces a worker to fail after the schema was restored.
    FileUtils.rm(
      Dir[File.join(@dump_directory, "*.dat*")].reject { |p| p.end_with?("toc.dat") }.first,
    )

    expect { restorer.send(:restore_dump) }.to raise_error(
      BackupRestore::DatabaseRestoreError,
      /pg_restore failed/,
    )

    BackupRestore.stubs(:can_rollback?).returns(true)
    BackupRestore
      .expects(:move_tables_between_schemas)
      .with do |source, destination|
        expect([source, destination]).to eq(%w[backup public])
        @connection.exec(
          BackupRestore.move_tables_between_schemas_sql(source, destination, @connection.user),
        )
      end
    restorer.rollback

    expect(@connection.exec("SELECT name FROM parents ORDER BY id").column_values(0)).to eq(
      ["first", "second", "keep on rollback"],
    )
    expect(@connection.exec("SELECT count(*) FROM children").getvalue(0, 0)).to eq("2")
  end
end
