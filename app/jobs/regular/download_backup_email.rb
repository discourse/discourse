# frozen_string_literal: true

module Jobs

  class DownloadBackupEmail < ::Jobs::Base

    sidekiq_options queue: 'critical'

    def execute(args)
      user_id = args[:user_id]
      user = User.find_by(id: user_id)
      raise Discourse::InvalidParameters.new(:user_id) unless user

      backup_file_path = args[:backup_file_path]
      raise Discourse::InvalidParameters.new(:backup_file_path) if backup_file_path.blank?

      backup_file_path = URI(backup_file_path)
      backup_file_path.query = { token: EmailBackupToken.set(user.id) }.to_param

      message = DownloadBackupMailer.send_email(user.email, backup_file_path.to_s)
      Email::Sender.new(message, :download_backup_message).send
    end

  end

end
