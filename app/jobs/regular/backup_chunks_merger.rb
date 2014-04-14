module Jobs

  class BackupChunksMerger < Jobs::Base
    sidekiq_options retry: false

    def execute(args)
      filename   = args[:filename]
      identifier = args[:identifier]
      chunks     = args[:chunks].to_i

      raise Discourse::InvalidParameters.new(:filename)   if filename.blank?
      raise Discourse::InvalidParameters.new(:identifier) if identifier.blank?
      raise Discourse::InvalidParameters.new(:chunks)     if chunks <= 0

      backup_path = "#{Backup.base_directory}/#{filename}"
      tmp_backup_path = "#{backup_path}.tmp"

      # delete destination files
      File.delete(backup_path) rescue nil
      File.delete(tmp_backup_path) rescue nil

      # merge all the chunks
      File.open(tmp_backup_path, "a") do |backup|
        (1..chunks).each do |chunk_number|
          # path to chunk
          chunk_path = Backup.chunk_path(identifier, filename, chunk_number)
          # add chunk to backup
          backup << File.open(chunk_path).read
        end
      end
      
      # rename tmp backup to final backup name
      FileUtils.mv(tmp_backup_path, backup_path, force: true)

      # remove tmp directory
      tmp_directory = File.dirname(Backup.chunk_path(identifier, filename, 0))
      FileUtils.rm_rf(tmp_directory) rescue nil
    end

  end

end
