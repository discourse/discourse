require_dependency 'email/message_builder'

class DownloadBackupMailer < ActionMailer::Base
  include Email::BuildEmailHelper

  def send_email(to_address, backup_file_path)
    build_email(to_address, template: 'download_backup_mailer', backup_file_path: backup_file_path)
  end
end
