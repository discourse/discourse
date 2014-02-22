module Jobs

  class BackupChunksMerger < Jobs::Base
    sidekiq_options retry: false

    def execute(args)
      filename   = args[:filename]
      identifier = args[:identifier]
      chunks     = args[:chunks].to_i

      raise Discourse::InvalidParameters.new(:filename) if filename.blank?
      raise Discourse::InvalidParameters.new(:identifier) if identifier.blank?
      raise Discourse::InvalidParameters.new(:chunks) if chunks <= 0

      backup = "#{Backup.base_directory}/#{filename}"

      # delete destination
      File.delete(backup) rescue nil

      # merge all the chunks
      File.open(backup, "a") do |backup|
        (1..chunks).each do |chunk_number|
          # path to chunk
          path = Backup.chunk_path(identifier, filename, chunk_number)
          # add chunk to backup
          backup << File.open(path).read
          # delete chunk
          File.delete(path) rescue nil
        end
      end

      # remove tmp directory
      FileUtils.rm_rf(directory) rescue nil
    end

  end

end
