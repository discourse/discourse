require_dependency 'import/json_decoder'
require_dependency 'import/import'
require_dependency 'import/adapter/base'
require_dependency 'directory_helper'

(Dir.entries(File.join( Rails.root, 'lib', 'import', 'adapter' )) - ['.', '..', 'base.rb']).each do |f|
  require_dependency "import/adapter/#{f}"
end

module Jobs

  class Importer < Jobs::Base

    include DirectoryHelper
    sidekiq_options retry: false

    BACKUP_SCHEMA = 'backup'

    def initialize
      @index_definitions = {}
      @format = :json
      @warnings = []
    end

    def execute(args)
      ordered_models_for_import.each { |model| model.primary_key } # a HACK to workaround cache problems

      raise Import::ImportDisabledError   unless SiteSetting.allow_import?
      raise Import::ImportInProgressError if Import::is_import_running?
      raise Export::ExportInProgressError if Export::is_export_running?

      # Disable printing of NOTICE, DETAIL and other unimportant messages from postgresql
      User.exec_sql("SET client_min_messages TO WARNING")

      @format = args[:format] || :json
      @archive_filename = args[:filename]
      if args[:user_id]
        # After the import is done, we'll need to reload the user record and make sure it's the same person
        # before sending a notification
        user = User.where(id: args[:user_id].to_i).first
        @user_info = { user_id: user.id, email: user.email }
      else
        @user_info = nil
      end

      start_import
      backup_tables
      begin
        load_data
        create_indexes
        extract_uploads
      rescue
        log "Performing a ROLLBACK because something went wrong!"
        rollback
        raise
      end
    ensure
      finish_import
    end

    def ordered_models_for_import
      Export.models_included_in_export
    end

    def start_import
      if @format != :json
        raise Import::FormatInvalidError
      elsif @archive_filename.nil?
        raise Import::FilenameMissingError
      else
        extract_files
        @decoder = Import::JsonDecoder.new( File.join(tmp_directory('import'), 'tables.json') )
        Import.set_import_started
        Discourse.enable_maintenance_mode
      end
      self
    end

    def extract_files
      FileUtils.cd( tmp_directory('import') ) do
        `tar xvzf #{@archive_filename} tables.json`
      end
    end

    def backup_tables
      log "  Backing up tables"
      ActiveRecord::Base.transaction do
        create_backup_schema
        ordered_models_for_import.each do |model|
          backup_and_setup_table( model )
        end
      end
      self
    end

    def create_backup_schema
      User.exec_sql("DROP SCHEMA IF EXISTS #{BACKUP_SCHEMA} CASCADE")
      User.exec_sql("CREATE SCHEMA #{BACKUP_SCHEMA}")
      self
    end

    def backup_and_setup_table( model )
      log "    #{model.table_name}"
      @index_definitions[model.table_name] = model.exec_sql("SELECT indexdef FROM pg_indexes WHERE tablename = '#{model.table_name}' and schemaname = 'public';").map { |x| x['indexdef'] }
      model.exec_sql("ALTER TABLE #{model.table_name} SET SCHEMA #{BACKUP_SCHEMA}")
      model.exec_sql("CREATE TABLE #{model.table_name} (LIKE #{BACKUP_SCHEMA}.#{model.table_name} INCLUDING DEFAULTS INCLUDING CONSTRAINTS INCLUDING COMMENTS INCLUDING STORAGE);")
      self
    end

    def load_data
      log "  Importing data"
      @decoder.start(
        callbacks: {
          schema_info: method(:set_schema_info),
          table_data: method(:load_table)
        }
      )
      self
    end

    def set_schema_info(arg)
      if arg[:source] && arg[:source].downcase == 'discourse'
        if arg[:version] && arg[:version] <= Export.current_schema_version
          @export_schema_version = arg[:version]
          if arg[:table_count] == ordered_models_for_import.size
            true
          else
            raise Import::WrongTableCountError.new("Expected to find #{ordered_models_for_import.size} tables, but export file has #{arg[:table_count]} tables!")
          end
        elsif arg[:version].nil?
          raise ArgumentError.new("The schema version must be provided.")
        else
          raise Import::UnsupportedSchemaVersion.new("Export file is from a newer version of Discourse. Upgrade and run migrations to import this file.")
        end
      else
        raise Import::UnsupportedExportSource
      end
    end

    def load_table(table_name, fields_arg, row_data, row_count)
      fields = fields_arg.dup
      model = Export::models_included_in_export.find { |m| m.table_name == table_name }
      if model

        @adapters ||= Import.adapters_for_version( @export_schema_version )

        log "    #{table_name}: #{row_count} rows"

        if @adapters[table_name]
          @adapters[table_name].each do |adapter|
            fields = adapter.apply_to_column_names(table_name, fields)
          end
        end

        if fields.size > model.columns.size
          raise Import::WrongFieldCountError.new("Table #{table_name} is expected to have #{model.columns.size} fields, but got #{fields.size}! Maybe your Discourse server is older than the server that this export file comes from?")
        end

        # If there are fewer fields in the data than the model has, then insert only those fields and
        # hope that the table uses default values or allows null for the missing columns.
        # If the table doesn't have defaults or is not nullable, then a migration adapter should have been created
        # along with the migration.

        column_info = model.columns

        col_num = -1
        rows = row_data.map do |row|
          if @adapters[table_name]
            @adapters[table_name].each do |adapter|
              row = adapter.apply_to_row(table_name, row)
            end
          end
          row
        end.transpose.map do |col_values|
          col_num += 1
          case column_info[col_num].type
          when :boolean
            col_values.map { |v| v.nil? ? nil : (v == 'f' ? false : true) }
          else
            col_values
          end
        end.transpose

        parameter_markers = fields.map {|x| "?"}.join(',')
        sql_stmt = "INSERT INTO #{table_name} (#{fields.join(',')}) VALUES (#{parameter_markers})"

        rows.each do |row|
          User.exec_sql(sql_stmt, *row)
        end

        true
      else
        add_warning "Export file contained an unrecognized table named: #{table_name}! It was ignored."
      end
    end

    def create_indexes
      log "  Creating indexes"
      ordered_models_for_import.each do |model|
        log "    #{model.table_name}"
        @index_definitions[model.table_name].each do |indexdef|
          model.exec_sql( indexdef )
        end

        # The indexdef statements don't create the primary keys, so we need to find the primary key and do it ourselves.
        pkey_index_def = @index_definitions[model.table_name].find { |ixdef| ixdef =~ / ([\S]{1,}_pkey) / }
        if pkey_index_def && pkey_index_name = / ([\S]{1,}_pkey) /.match(pkey_index_def)[1]
          model.exec_sql( "ALTER TABLE ONLY #{model.table_name} ADD PRIMARY KEY USING INDEX #{pkey_index_name}" )
        end

        if model.columns.map(&:name).include?('id')
          max_id = model.exec_sql("SELECT MAX(id) AS max FROM #{model.table_name}")[0]['max'].to_i + 1
          seq_name = "#{model.table_name}_id_seq"
          model.exec_sql("CREATE SEQUENCE #{seq_name} START WITH #{max_id} INCREMENT BY 1 NO MINVALUE NO MAXVALUE CACHE 1")
          model.exec_sql("ALTER SEQUENCE #{seq_name} OWNED BY #{model.table_name}.id")
          model.exec_sql("ALTER TABLE #{model.table_name} ALTER COLUMN id SET DEFAULT nextval('#{seq_name}')")
        end
      end
      self
    end

    def extract_uploads
      if `tar tf #{@archive_filename} | grep "uploads/"`.present?
        FileUtils.cd( File.join(Rails.root, 'public') ) do
          `tar -xz --keep-newer-files -f #{@archive_filename} uploads/`
        end
      end
    end

    def rollback
      ordered_models_for_import.each do |model|
        log "  #{model.table_name}"
        model.exec_sql("DROP TABLE IF EXISTS #{model.table_name}") rescue nil
        begin
          model.exec_sql("ALTER TABLE #{BACKUP_SCHEMA}.#{model.table_name} SET SCHEMA public")
        rescue => e
          log "      Failed to restore. #{e.class.name}: #{e.message}"
        end
      end
    end

    def finish_import
      Import.set_import_is_not_running
      Discourse.disable_maintenance_mode
      remove_tmp_directory('import')

      if @warnings.size > 0
        log "WARNINGS:"
        @warnings.each do |message|
          log "  #{message}"
        end
      end

      # send_notification
    end

    def send_notification
      # Doesn't work.  "WARNING: Can't mass-assign protected attributes: created_at"
      # Still a problem with the activerecord schema_cache I think.
      # if @user_info && @user_info[:user_id]
      #   user = User.where(id: @user_info[:user_id]).first
      #   if user && user.email == @user_info[:email]
      #     SystemMessage.new(user).create('import_succeeded')
      #   end
      # end
      true
    end

    def add_warning(message)
      @warnings << message
    end

  end

end
