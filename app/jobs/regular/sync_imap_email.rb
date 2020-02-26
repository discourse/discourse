# frozen_string_literal: true

require_dependency 'imap/sync'

module Jobs
  class SyncImapEmail < ::Jobs::Base
    sidekiq_options retry: 3

    def execute(args)
      return if !SiteSetting.enable_imap

      group = Group.find_by(id: args[:group_id])
      email = args[:email]

      if email['RFC822'].present?
        begin
          receiver = Email::Receiver.new(
            Base64.decode64(email['RFC822']),
            allow_auto_generated: true,
            import_mode: args[:import_mode],
            destinations: [group],
            uid_validity: args[:uid_validity],
            uid: email['UID']
          )
          receiver.process!
          incoming_email = receiver.incoming_email
        rescue Email::Receiver::ProcessingError => e
          Rails.logger.warn("[IMAP] Could not process email with Message-ID = #{receiver.message_id}")
          return
        end
      else
        incoming_email = IncomingEmail.find_by(
          imap_uid_validity: args[:uid_validity],
          imap_uid: email['UID']
        )

        if incoming_email.blank?
          Rails.logger.warn("[IMAP] Could not find old email (UIDVALIDITY = #{args[:uid_validity]}, UID = #{email['UID']})")
          return
        end
      end

      imap_sync = Imap::Sync.for_group(group, offline: true)
      imap_sync.update_topic(email, incoming_email, mailbox_name: args[:mailbox_name] || group.imap_mailbox_name)
    end
  end
end
