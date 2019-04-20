require "net/imap"

module Imap
  class Sync

    def self.for_group(group, opts = {})
      if group.imap_server == "imap.gmail.com"
        opts[:provider] ||= Imap::Providers::Gmail
      else
        opts[:provider] ||= Imap::Providers::Generic
      end

      Imap::Sync.new(group, opts)
    end

    def initialize(group, opts = {})
      @group = group

      opts[:provider] ||= Imap::Providers::Generic
      @provider = opts[:provider].new(group.imap_server,
        port: group.imap_port,
        ssl: group.imap_ssl,
        username: group.email_username,
        password: group.email_password
      )

      connect! if !opts[:offline]
    end

    def connect!
      @provider.connect!
    end

    def disconnect!
      @provider.disconnect!
    end

    def process(mailbox, idle = false)
      # Server-to-Discourse sync:
      #   - check mailbox validity
      #   - discover changes to old messages (flags and labels)
      #   - fetch new messages
      @status = @provider.open_mailbox(mailbox)

      if @status[:uid_validity] != mailbox.uid_validity
        Rails.logger.warn("UIDVALIDITY does not match, invalidating IMAP cache and resync emails for #{@group.name}/#{mailbox.name}.")
        mailbox.last_seen_uid = 0
      end

      if idle
        if !@provider.can?("IDLE")
          return Rails.logger.warn("IMAP server for #{@group.name} does not support IDLE.")
        end

        last_response_name = nil
        @provider.imap.idle do |resp|
          if resp.kind_of?(Net::IMAP::UntaggedResponse) && resp.name == "EXISTS"
            last_response_name = resp.name
            @provider.imap.idle_done
          end
        end

        old_uids = []
        new_uids = @provider.imap.uid_search("NOT SEEN").filter { |uid| uid > mailbox.last_seen_uid }
      else
        # Fetching UIDs of already synchronized and newly arrived emails.
        # Some emails may be considered newly arrived even though they have
        # been previously processed if the mailbox has been invalidated
        # (UIDVALIDITY changed).
        if mailbox.last_seen_uid == 0
          old_uids = []
          new_uids = @provider.uids
        else
          old_uids = @provider.uids(to: mailbox.last_seen_uid) # 1 .. seen
          new_uids = @provider.uids(from: mailbox.last_seen_uid + 1) # seen+1 .. inf
        end
      end

      import_mode = new_uids.size > SiteSetting.imap_batch_import_email if SiteSetting.imap_batch_import_email > -1
      old_uids = old_uids.sample(SiteSetting.imap_poll_old_emails) if SiteSetting.imap_poll_old_emails > 0
      new_uids = new_uids[0..SiteSetting.imap_poll_new_emails] if SiteSetting.imap_poll_new_emails > 0

      if old_uids.present?
        emails = @provider.emails(mailbox, old_uids, ["UID", "FLAGS", "LABELS"])
        emails.each do |email|
          Jobs.enqueue(:sync_imap_email,
            group_id: @group.id,
            mailbox_name: mailbox.name,
            uid_validity: @status[:uid_validity],
            email: email,
          )
        end
      end

      if new_uids.present?
        emails = @provider.emails(mailbox, new_uids, ["UID", "FLAGS", "LABELS", "RFC822"])
        emails.each do |email|
          # Pass content as it is and let `Email::Receiver` handle email
          # encoding.
          email["RFC822"] = Base64.encode64(email["RFC822"])

          Jobs.enqueue(:sync_imap_email,
            group_id: @group.id,
            mailbox_name: mailbox.name,
            uid_validity: @status[:uid_validity],
            email: email,
            import_mode: import_mode,
          )
        end
      end

      mailbox.uid_validity = @status[:uid_validity]
      mailbox.last_seen_uid = new_uids.last || 0
      mailbox.save!

      # Discourse-to-server sync:
      #   - sync flags and labels
      if !idle && !SiteSetting.imap_read_only
        @provider.open_mailbox(mailbox, true)
        IncomingEmail.where(imap_sync: true).each do |incoming_email|
          update_email(mailbox, incoming_email)
        end
      end
    end

    def update_topic(email, incoming_email, opts = {})
      return if incoming_email&.post&.post_number != 1 || incoming_email.imap_sync

      topic = incoming_email.topic

      update_topic_archived_state(email, topic, opts)
      update_topic_tags(email, topic, opts)
    end

    private

    def update_topic_archived_state(email, topic, opts = {})
      topic_is_archived = topic.group_archived_messages.length > 0
      email_is_archived = !email["LABELS"].include?("\\Inbox") && !email["LABELS"].include?("INBOX")

      if topic_is_archived && !email_is_archived
        GroupArchivedMessage.move_to_inbox!(@group.id, topic, skip_imap_sync: true)
      elsif !topic_is_archived && email_is_archived
        GroupArchivedMessage.archive!(@group.id, topic, skip_imap_sync: true)
      end
    end

    def update_topic_tags(email, topic, opts = {})
      tags = []
      tags << @provider.to_tag(opts[:mailbox_name]) if opts[:mailbox_name]
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
      return if !SiteSetting.tagging_enabled || !SiteSetting.allow_staff_to_tag_pms
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
