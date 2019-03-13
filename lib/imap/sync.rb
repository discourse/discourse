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

      @labels = @provider.labels
    end

    def process(mailbox)
      @mailbox = mailbox

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
        emails = @provider.emails(old_uids, ["UID", "FLAGS", "LABELS"])
        emails.each do |email|
          incoming_email = IncomingEmail.find_by(
            imap_uid_validity: @status[:uid_validity],
            imap_uid: email["UID"]
          )

          update_topic(email, incoming_email)
        end
      end

      if new_uids.present?
        emails = @provider.emails(new_uids, ["UID", "FLAGS", "LABELS", "RFC822"])
        emails.each do |email|
          begin
            receiver = Email::Receiver.new(email["RFC822"],
              destinations: [{ type: :group, obj: @group }],
              uid_validity: @status[:uid_validity],
              uid: email["UID"]
            )
            receiver.process!

            update_topic(email, receiver.incoming_email)

            mailbox.last_seen_uid = email["UID"]
          rescue Email::Receiver::ProcessingError => e
            p e
          end
        end
      end

      mailbox.update!(uid_validity: @status[:uid_validity])

      @provider.select_mailbox(mailbox)

      # TODO: Client-to-server sync:
      #       - sending emails using SMTP
      #       - sync labels

      # IncomingEmail.where(imap_sync: true).each do |incoming_email|
      #   update_email(incoming_email)
      # end
    end

    def disconnect!
      @provider.disconnect!
    end

    def update_topic(email, incoming_email)
      return if incoming_email&.post&.post_number != 1 || incoming_email.imap_sync

      labels = email["LABELS"]
      flags = email["FLAGS"]
      topic = incoming_email.topic

      # Sync archived status of topic.
      old_archived = topic.group_archived_messages.length > 0
      new_archived = !labels.include?("\\Inbox")

      if old_archived && !new_archived
        GroupArchivedMessage.move_to_inbox!(@group.id, topic)
      elsif !old_archived && new_archived
        GroupArchivedMessage.archive!(@group.id, topic)
      end

      # Sync email flags and labels with topic tags.
      tags = [ to_tag(@mailbox.name), flags.include?(:Seen) && "seen" ]
      labels.each { |label| tags << to_tag(label) }
      tags.reject!(&:blank?)

      # TODO: Optimize tagging.
      topic.tags = []
      DiscourseTagging.tag_topic_by_names(topic, Guardian.new(Discourse.system_user), tags)
    end

    def update_email(incoming_email)
      return if incoming_email&.post&.post_number != 1 || !incoming_email.imap_sync
      return unless email = @provider.emails(incoming_email.imap_uid, ["FLAGS", "LABELS"]).first
      # incoming_email.update(imap_sync: false)

      labels = email["LABELS"]
      flags = email["FLAGS"]
      topic = incoming_email.topic

      # Sync topic status and labels with email flags and labels.
      tags = topic.tags.pluck(:name)
      new_flags = tags.map { |tag| tag_to_flag(tag) }.reject(&:blank?)
      new_labels = tags.map { |tag| tag_to_label(tag) }.reject(&:blank?)
      new_labels << "\\Inbox" if topic.group_archived_messages.length == 0
      store(incoming_email.imap_uid, "FLAGS", flags, new_flags)
      store(incoming_email.imap_uid, "LABELS", labels, new_labels)
    end

    def store(uid, attribute, old_set, new_set)
      additions = new_set.reject { |val| old_set.include?(val) }
      @provider.uid_store(uid, "+#{attribute}", additions) if additions.length > 0
      removals = old_set.reject { |val| new_set.include?(val) }
      @provider.uid_store(uid, "-#{attribute}", removals) if removals.length > 0
    end

    def tag_to_flag(tag)
      :Seen if tag == "seen"
    end

    def tag_to_label(tag)
      @labels[tag]
    end

    def to_tag(label)
      label = label.to_s.gsub("[Gmail]/", "")
      label = DiscourseTagging.clean_tag(label.to_s)

      label if label != "all-mail" && label != "inbox" && label != "sent"
    end
  end

end
