require "net/imap"

module Imap
  class Sync
    def initialize(group, provider = Imap::Providers::Generic)
      @group = group

      @provider = provider.new(group.imap_server,
        port: group.imap_port,
        ssl: group.imap_ssl,
        username: group.email_username,
        password: group.email_password
      )
      @provider.connect!
    end

    def disconnect!
      @provider.disconnect!
    end

    def process(mailbox)
      # Server-to-Discourse sync:
      #   - check mailbox validity
      #   - discover changes to old messages (flags and labels)
      #   - fetch new messages
      @status = @provider.open_mailbox(mailbox)

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
        new_uids = @provider.uids
      else
        old_uids = @provider.uids(to: mailbox.last_seen_uid) # 1 .. seen
        new_uids = @provider.uids(from: mailbox.last_seen_uid + 1) # seen+1 .. inf
      end

      if old_uids.present?
        emails = @provider.emails(mailbox, old_uids, ["UID", "FLAGS", "LABELS"])
        emails.each do |email|
          incoming_email = IncomingEmail.find_by(
            imap_uid_validity: @status[:uid_validity],
            imap_uid: email["UID"]
          )

          update_topic(mailbox, email, incoming_email)
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

            update_topic(mailbox, email, receiver.incoming_email)

            mailbox.last_seen_uid = email["UID"]
          rescue Email::Receiver::ProcessingError => e
          end
        end
      end

      mailbox.update!(uid_validity: @status[:uid_validity])

      # Discourse-to-server sync:
      #   - sync flags and labels
      @provider.open_mailbox(mailbox, true)
      IncomingEmail.where(imap_sync: true).each do |incoming_email|
        update_email(mailbox, incoming_email)
      end
    end

    private

    def update_topic(mailbox, email, incoming_email)
      return if incoming_email&.post&.post_number != 1 || incoming_email.imap_sync

      topic = incoming_email.topic

      update_topic_archived_state(mailbox, email, topic)
      update_topic_tags(mailbox, email, topic)
    end

    def update_topic_archived_state(mailbox, email, topic)
      topic_is_archived = topic.group_archived_messages.length > 0
      email_is_archived = !email["LABELS"].include?("\\Inbox")

      if topic_is_archived && !email_is_archived
        GroupArchivedMessage.move_to_inbox!(@group.id, topic, skip_imap_sync: true)
      elsif !topic_is_archived && email_is_archived
        GroupArchivedMessage.archive!(@group.id, topic, skip_imap_sync: true)
      end
    end

    def update_topic_tags(mailbox, email, topic)
      tags = [ @provider.to_tag(mailbox.name) ]
      email["FLAGS"].each { |flag| tags << @provider.to_tag(flag) }
      email["LABELS"].each { |label| tags << @provider.to_tag(label) }
      tags.reject!(&:blank?)
      tags.uniq!

      # TODO: Optimize tagging.
      # `DiscourseTagging.tag_topic_by_names` does a lot of lookups in the
      # database and some of them could be cached in this context.
      DiscourseTagging.tag_topic_by_names(topic, Guardian.new(Discourse.system_user), tags)
    end

    def update_email(mailbox, incoming_email)
      return if incoming_email&.post&.post_number != 1 || !incoming_email.imap_sync
      return unless email = @provider.emails(mailbox, incoming_email.imap_uid, ["FLAGS", "LABELS"]).first
      incoming_email.update(imap_sync: false)

      labels = email["LABELS"]
      flags = email["FLAGS"]
      topic = incoming_email.topic

      # Sync topic status and labels with email flags and labels.
      tags = topic.tags.pluck(:name)
      new_flags = tags.map { |tag| @provider.tag_to_flag(tag) }.reject(&:blank?)
      new_labels = tags.map { |tag| @provider.tag_to_label(tag) }.reject(&:blank?)
      new_labels << "\\Inbox" if topic.group_archived_messages.length == 0
      @provider.store(incoming_email.imap_uid, "FLAGS", flags, new_flags)
      @provider.store(incoming_email.imap_uid, "LABELS", labels, new_labels)
    end
  end

end
