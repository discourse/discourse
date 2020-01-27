# frozen_string_literal: true

module BackupRestore
  class Factory
    def initialize(user_id: nil, client_id: nil)
      @user_id = user_id
      @client_id = client_id
    end

    def logger
      @logger ||= Logger.new(user_id: @user_id, client_id: @client_id)
    end

    def create_system_interface
      SystemInterface.new(logger)
    end

    def create_uploads_restorer
      UploadsRestorer.new(logger)
    end

    def create_database_restorer(current_db)
      DatabaseRestorer.new(logger, current_db)
    end

    def create_meta_data_handler(filename, tmp_directory)
      MetaDataHandler.new(logger, filename, tmp_directory)
    end

    def create_backup_file_handler(filename, current_db)
      BackupFileHandler.new(logger, filename, current_db)
    end
  end
end
