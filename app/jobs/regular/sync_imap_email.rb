require_dependency 'imap'

module Jobs
  class SyncImapEmail < Jobs::Base
    sidekiq_options retry: 3

    def execute(args)
      @args = args

      group = Group.find_by(id: @args[:group_id])
      email = args[:email]

      if email["RFC822"].present?
        begin
          receiver = Email::Receiver.new(Base64.decode64(email["RFC822"]),
            force_sync: true,
            import_mode: args[:import_mode],
            destinations: [{ type: :group, obj: group }],
            uid_validity: args[:uid_validity],
            uid: email["UID"]
          )
          receiver.process!
          incoming_email = receiver.incoming_email
        rescue Email::Receiver::ProcessingError => e
          Rails.logger.warn("Could not process (#{args[:uid_validity]}, #{email['UID']}): #{e.message}")
        end
      else
        incoming_email = IncomingEmail.find_by(
          imap_uid_validity: args[:uid_validity],
          imap_uid: email["UID"]
        )
      end

      imap_sync = Imap::Sync.for_group(group, offline: true)
      imap_sync.update_topic(email, incoming_email, mailbox_name: args[:mailbox_name])

      nil
    end
  end
end
