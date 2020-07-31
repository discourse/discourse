# frozen_string_literal: true

require 'net/imap'

module Imap
  class Sync
    class Logger
      def self.log(msg, level = :debug)
        if ENV['DISCOURSE_EMAIL_SYNC_LOG_OVERRIDE'] == 'warn'
          Rails.logger.warn(msg)
        else
          Rails.logger.send(level, msg)
        end
      end
    end

    def self.for_group(group, opts = {})
      if group.imap_server == 'imap.gmail.com'
        opts[:provider] ||= Imap::Providers::Gmail
      end

      Imap::Sync.new(group, opts)
    end

    def initialize(group, opts = {})
      @group = group

      provider_klass ||= opts[:provider] || Imap::Providers::Generic
      @provider = provider_klass.new(
        @group.imap_server,
        port: @group.imap_port,
        ssl: @group.imap_ssl,
        username: @group.email_username,
        password: @group.email_password
      )

      connect!
    end

    def connect!
      @provider.connect!
    end

    def disconnect!
      @provider.disconnect!
    end

    def disconnected?
      @provider.disconnected?
    end

    def can_idle?
      SiteSetting.enable_imap_idle && @provider.can?('IDLE')
    end

    def process(idle: false, import_limit: nil, old_emails_limit: nil, new_emails_limit: nil)
      raise 'disconnected' if disconnected?

      import_limit     ||= SiteSetting.imap_batch_import_email
      old_emails_limit ||= SiteSetting.imap_polling_old_emails
      new_emails_limit ||= SiteSetting.imap_polling_new_emails

      # IMAP server -> Discourse (download): discovers updates to old emails
      # (synced emails) and fetches new emails.

      # TODO: Use `Net::IMAP.encode_utf7(@group.imap_mailbox_name)`?
      @status = @provider.open_mailbox(@group.imap_mailbox_name)

      if @status[:uid_validity] != @group.imap_uid_validity
        # If UID validity changes, the whole mailbox must be synchronized (all
        # emails are considered new and will be associated to existent topics
        # in Email::Reciever by matching Message-Ids).
        Logger.log("[IMAP] (#{@group.name}) UIDVALIDITY = #{@status[:uid_validity]} does not match expected #{@group.imap_uid_validity}, invalidating IMAP cache and resyncing emails for group #{@group.name} and mailbox #{@group.imap_mailbox_name}", :warn)
        @group.imap_last_uid = 0
      end

      if idle && !can_idle?
        Logger.log("[IMAP] (#{@group.name}) IMAP server for group cannot IDLE", :warn)
        idle = false
      end

      if idle
        raise 'IMAP IDLE is disabled' if !SiteSetting.enable_imap_idle

        # Thread goes into sleep and it is better to return any connection
        # back to the pool.
        ActiveRecord::Base.connection_handler.clear_active_connections!

        idle_polling_mins = SiteSetting.imap_polling_period_mins.minutes.to_i
        Logger.log("[IMAP] (#{@group.name}) Going IDLE for #{idle_polling_mins} seconds to wait for more work")

        @provider.imap.idle(idle_polling_mins) do |resp|
          if resp.kind_of?(Net::IMAP::UntaggedResponse) && resp.name == 'EXISTS'
            @provider.imap.idle_done
          end
        end
      end

      # Fetching UIDs of old (already imported into Discourse, but might need
      # update) and new (not downloaded yet) emails.
      if @group.imap_last_uid == 0
        old_uids = []
        new_uids = @provider.uids
      else
        old_uids = @provider.uids(to: @group.imap_last_uid) # 1 .. seen
        new_uids = @provider.uids(from: @group.imap_last_uid + 1) # seen+1 .. inf
      end

      # Sometimes, new_uids contains elements from old_uids.
      new_uids = new_uids - old_uids

      Logger.log("[IMAP] (#{@group.name}) Remote email server has #{old_uids.size} old emails and #{new_uids.size} new emails")

      all_old_uids_size = old_uids.size
      all_new_uids_size = new_uids.size

      @group.update_columns(
        imap_last_error: nil,
        imap_old_emails: all_old_uids_size,
        imap_new_emails: all_new_uids_size
      )

      import_mode = import_limit > -1 && new_uids.size > import_limit
      old_uids = old_uids.sample(old_emails_limit).sort! if old_emails_limit > -1
      new_uids = new_uids[0..new_emails_limit - 1] if new_emails_limit > 0

      if old_uids.present?
        process_old_uids(old_uids)
      end

      if new_uids.present?
        process_new_uids(new_uids, import_mode, all_old_uids_size, all_new_uids_size)
      end

      # Discourse -> IMAP server (upload): syncs updated flags and labels.
      sync_to_server

      { remaining: all_new_uids_size - new_uids.size }
    end

    def update_topic(email, incoming_email, opts = {})
      return if !incoming_email ||
                incoming_email.imap_sync ||
                !incoming_email.topic ||
                incoming_email.post&.post_number != 1

      update_topic_archived_state(email, incoming_email, opts)
      update_topic_tags(email, incoming_email, opts)
    end

    private

    def process_old_uids(old_uids)
      Logger.log("[IMAP] (#{@group.name}) Syncing #{old_uids.size} randomly-selected old emails")
      emails = @provider.emails(old_uids, ['UID', 'FLAGS', 'LABELS', 'ENVELOPE'])
      emails.each do |email|
        incoming_email = IncomingEmail.find_by(
          imap_uid_validity: @status[:uid_validity],
          imap_uid: email['UID'],
          imap_group_id: @group.id
        )

        if incoming_email.present?
          update_topic(email, incoming_email, mailbox_name: @group.imap_mailbox_name)
        else
          # try finding email by message-id instead, we may be able to set the uid etc.
          incoming_email = IncomingEmail.where(
            message_id: email['ENVELOPE'].message_id.tr("<>", ""),
            imap_uid: nil,
            imap_uid_validity: nil
          ).where("to_addresses LIKE '%#{@group.email_username}%'").first

          if incoming_email
            incoming_email.update(
              imap_uid_validity: @status[:uid_validity],
              imap_uid: email['UID'],
              imap_group_id: @group.id
            )
            update_topic(email, incoming_email, mailbox_name: @group.imap_mailbox_name)
          else
            Logger.log("[IMAP] (#{@group.name}) Could not find old email (UIDVALIDITY = #{@status[:uid_validity]}, UID = #{email['UID']})", :warn)
          end
        end
      end
    end

    def process_new_uids(new_uids, import_mode, all_old_uids_size, all_new_uids_size)
      Logger.log("[IMAP] (#{@group.name}) Syncing #{new_uids.size} new emails (oldest first)")

      emails = @provider.emails(new_uids, ['UID', 'FLAGS', 'LABELS', 'RFC822'])
      processed = 0

      emails.each do |email|
        # Synchronously process emails because the order of emails matter
        # (for example replies must be processed after the original email
        # to have a topic where the reply can be posted).
        begin
          receiver = Email::Receiver.new(
            email['RFC822'],
            allow_auto_generated: true,
            import_mode: import_mode,
            destinations: [@group],
            imap_uid_validity: @status[:uid_validity],
            imap_uid: email['UID'],
            imap_group_id: @group.id
          )
          receiver.process!

          update_topic(email, receiver.incoming_email, mailbox_name: @group.imap_mailbox_name)
        rescue Email::Receiver::ProcessingError => e
          Logger.log("[IMAP] (#{@group.name}) Could not process (UIDVALIDITY = #{@status[:uid_validity]}, UID = #{email['UID']}): #{e.message}", :warn)
        end

        processed += 1
        @group.update_columns(
          imap_uid_validity: @status[:uid_validity],
          imap_last_uid: email['UID'],
          imap_old_emails: all_old_uids_size + processed,
          imap_new_emails: all_new_uids_size - processed
        )
      end
    end

    def sync_to_server
      return if !SiteSetting.enable_imap_write

      to_sync = IncomingEmail.where(imap_sync: true, imap_group_id: @group.id)
      if to_sync.size > 0
        @provider.open_mailbox(@group.imap_mailbox_name, write: true)
        to_sync.each do |incoming_email|
          Logger.log("[IMAP] (#{@group.name}) Updating email and incoming email ID = #{incoming_email.id}")
          update_email(incoming_email)
        end
      end
    end

    def update_topic_archived_state(email, incoming_email, opts = {})
      topic = incoming_email.topic

      topic_is_archived = topic.group_archived_messages.size > 0
      email_is_archived = !email['LABELS'].include?('\\Inbox') && !email['LABELS'].include?('INBOX')

      if topic_is_archived && !email_is_archived
        GroupArchivedMessage.move_to_inbox!(@group.id, topic, skip_imap_sync: true)
      elsif !topic_is_archived && email_is_archived
        GroupArchivedMessage.archive!(@group.id, topic, skip_imap_sync: true)
      end
    end

    def update_topic_tags(email, incoming_email, opts = {})
      group_email_regex = @group.email_username_regex
      topic = incoming_email.topic

      tags = Set.new

      # "Plus" part from the destination email address
      to_addresses = incoming_email.to_addresses&.split(";") || []
      cc_addresses = incoming_email.cc_addresses&.split(";") || []
      (to_addresses + cc_addresses).each do |address|
        if plus_part = address&.scan(group_email_regex)&.first&.first
          tags.add("plus:#{plus_part[1..-1]}") if plus_part.length > 0
        end
      end

      # Mailbox name
      tags.add(@provider.to_tag(opts[:mailbox_name])) if opts[:mailbox_name]

      # Flags and labels
      email['FLAGS'].each { |flag| tags.add(@provider.to_tag(flag)) }
      email['LABELS'].each { |label| tags.add(@provider.to_tag(label)) }

      tags.subtract([nil, ''])

      # TODO: Optimize tagging.
      # `DiscourseTagging.tag_topic_by_names` does a lot of lookups in the
      # database and some of them could be cached in this context.
      DiscourseTagging.tag_topic_by_names(topic, Guardian.new(Discourse.system_user), tags.to_a)
    end

    def update_email(incoming_email)
      return if !SiteSetting.tagging_enabled || !SiteSetting.allow_staff_to_tag_pms
      return if incoming_email&.post&.post_number != 1 || !incoming_email.imap_sync

      # if email is nil, the UID does not exist in the provider, meaning....
      #
      # A) the email has been deleted/moved to a different mailbox in the provider
      # B) the UID does not belong to the provider
      email = @provider.emails(incoming_email.imap_uid, ['FLAGS', 'LABELS']).first
      return if !email.present?

      incoming_email.update(imap_sync: false)

      labels = email['LABELS']
      flags = email['FLAGS']
      topic = incoming_email.topic

      # TODO: Delete remote email if topic no longer exists
      # new_flags << Net::IMAP::DELETED if !incoming_email.topic
      return if !topic

      # Sync topic status and labels with email flags and labels.
      tags = topic.tags.pluck(:name)
      new_flags = tags.map { |tag| @provider.tag_to_flag(tag) }.reject(&:blank?)
      new_labels = tags.map { |tag| @provider.tag_to_label(tag) }.reject(&:blank?)

      # the topic is archived, and the archive should be reflected in the IMAP
      # server
      topic_archived = topic.group_archived_messages.any?
      if !topic_archived
        new_labels << '\\Inbox'
      else
        Logger.log("[IMAP] (#{@group.name}) Archiving UID #{incoming_email.imap_uid}")
      end

      @provider.store(incoming_email.imap_uid, 'FLAGS', flags, new_flags)
      @provider.store(incoming_email.imap_uid, 'LABELS', labels, new_labels)

      # some providers need special handling for archiving. this way we preserve
      # any new tag-labels, and archive, even though it may cause extra requests
      # to the IMAP server
      @provider.archive(incoming_email.imap_uid)
    end
  end
end
