require_dependency 'email/sender'

module Jobs

  class DownloadBackupEmail < Jobs::Base

    sidekiq_options queue: 'critical'

    def execute(args)
      to_address = args[:to_address]
      backup_file_path = args[:backup_file_path]

      raise Discourse::InvalidParameters.new(:to_address) if to_address.blank?
      raise Discourse::InvalidParameters.new(:backup_file_path) if backup_file_path.blank?

      message = DownloadBackupMailer.send_email(to_address, backup_file_path)
      Email::Sender.new(message, :download_backup_message).send
    end

  end

end
