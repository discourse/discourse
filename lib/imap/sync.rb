require "net/imap"

module Imap
  class Sync
    def initialize(group, provider = Imap::Providers::Generic)
      @group = group

      @provider = provider.new(group.email_imap_server,
        port: group.email_imap_port,
        ssl: group.email_imap_ssl,
        username: group.email_username,
        password: group.email_password
      )

      @provider.connect!
    end

    def process(mailbox)
      @status = @provider.mailbox_status(mailbox)

      if @status[:uid_validity] != mailbox.uid_validity
        Rails.logger.warn("UIDVALIDITY does not match, invalidating IMAP cache and resync emails.")
        mailbox.last_seen_uid = 0
      end

      # Fetching UIDs of already synchronized and newly arrived emails.
      # Some emails may be considered newly arrived even though they have been
      # previously processed if the mailbox has been invalidated (UIDVALIDITY
      # changed).
      if mailbox.last_seen_uid == 0
        old_uids = []
        new_uids = @provider.all_uids
      else
        old_uids = @provider.uids_until(mailbox.last_seen_uid)
        new_uids = @provider.uids_from(mailbox.last_seen_uid)
      end

      if old_uids.present?
        emails = @provider.emails(mailbox, old_uids, ["UID", "FLAGS", "LABELS"])
        emails.each do |email|
          incoming_email = IncomingEmail.find_by(
            imap_uid_validity: @status[:uid_validity],
            imap_uid: email["UID"]
          )

          set_topic_archived_state(email, incoming_email, @group)
          set_topic_tags(incoming_email, email, mailbox, @provider)
        end
      end

      if new_uids.present?
        emails = @provider.emails(mailbox, new_uids, ["UID", "FLAGS", "LABELS", "RFC822"])
        emails.each do |email|
          begin
            receiver = Email::Receiver.new(email["RFC822"],
              destinations: [{ type: :group, obj: @group }],
              uid_validity: @status[:uid_validity],
              uid: email["UID"]
            )
            receiver.process!

            set_topic_archived_state(email, receiver.incoming_email, @group)
            set_topic_tags(receiver.incoming_email, email, mailbox, @provider)

            mailbox.last_seen_uid = email["UID"]
          rescue Email::Receiver::ProcessingError => e
          end
        end
      end

      mailbox.update!(uid_validity: @status[:uid_validity])

      @provider.select_mailbox(mailbox)

      # TODO: Client-to-server sync:
      #       - sending emails using SMTP
      #       - sync labels
      IncomingEmail.where(imap_sync: true).each do |incoming_email|
        update_email(incoming_email, mailbox, @provider)
      end
    end

    def disconnect!
      @provider.disconnect!
    end

    private

    def update_email(incoming_email, mailbox, provider)
      return if incoming_email&.post&.post_number != 1 || !incoming_email.imap_sync
      return unless email = @provider.emails(mailbox, incoming_email.imap_uid, ["FLAGS", "LABELS"]).first

      incoming_email.update(imap_sync: false)

      topic = incoming_email.topic
      provider.sync_flags(incoming_email.imap_uid, topic, email)
    end

    def set_topic_tags(incoming_email, email, mailbox, provider)
      return if incoming_email&.post&.post_number != 1 || incoming_email.imap_sync

      topic = incoming_email.topic
      labels = email["LABELS"]
      flags = email["FLAGS"]

      tags = [ provider.to_tag(mailbox.name), flags.include?(:Seen) && "seen" ]
      labels.each { |label| tags << provider.to_tag(label) }
      tags.reject!(&:blank?)

      # TODO: Optimize tagging.
      topic.tags = []
      DiscourseTagging.tag_topic_by_names(topic, Guardian.new(Discourse.system_user), tags)
    end

    def set_topic_archived_state(email, incoming_email, group)
      return if incoming_email&.post&.post_number != 1 || incoming_email.imap_sync

      topic = incoming_email.topic
      topic_is_archived = topic.group_archived_messages.length > 0
      email_is_archived = !email["LABELS"].include?("\\Inbox")
      if topic_is_archived && !email_is_archived
        GroupArchivedMessage.move_to_inbox!(group.id, topic)
      elsif !topic_is_archived && email_is_archived
        GroupArchivedMessage.archive!(group.id, topic)
      end
    end
  end

end
