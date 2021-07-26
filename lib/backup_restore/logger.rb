# frozen_string_literal: true

module BackupRestore
  class Logger
    attr_reader :logs

    def initialize(user_id: nil, client_id: nil)
      @user_id = user_id
      @client_id = client_id
      @publish_to_message_bus = @user_id.present? && @client_id.present?

      @logs = []
    end

    def log(message, ex = nil)
      return if Rails.env.test?

      timestamp = Time.now.strftime("%Y-%m-%d %H:%M:%S")
      puts(message)
      publish_log(message, timestamp)
      save_log(message, timestamp)

      if ex
        formatted_ex = "#{ex}\n" + ex.backtrace.join("\n")
        puts formatted_ex
        Rails.logger.error(formatted_ex)
      end
    end

    def self.save_log_to_upload(user:, filename: 'log.txt', logs:)
      Dir.mktmpdir do |dir|
        logfile = File.new(File.join(dir, filename), 'w')
        logfile.write(Discourse::Utils.pretty_logs(logs))
        logfile.close

        zipfile = Compression::Zip.new.compress(dir, filename)
        upload = File.open(zipfile) do |file|
          UploadCreator.new(
            file,
            File.basename(zipfile),
            type: 'backup_logs',
            for_export: 'true'
          ).create_for(user.id)
        end

        if !upload.persisted?
          Rails.logger.warn("Failed to upload the backup logs file #{zipfile}")
        end

        upload
      end
    end

    protected

    def publish_log(message, timestamp)
      return unless @publish_to_message_bus
      data = { timestamp: timestamp, operation: "restore", message: message }
      MessageBus.publish(BackupRestore::LOGS_CHANNEL, data, user_ids: [@user_id], client_ids: [@client_id])
    end

    def save_log(message, timestamp)
      @logs << "[#{timestamp}] #{message}"
    end
  end
end
