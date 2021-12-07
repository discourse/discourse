# frozen_string_literal: true

require 'net/imap'

module Imap
  class Sync
    def initialize(group, opts = {})
      @group = group
      @provider = Imap::Providers::Detector.init_with_detected_provider(@group.imap_config)
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
        # in Email::Receiver by matching Message-Ids).
        ImapSyncLog.warn("UIDVALIDITY = #{@status[:uid_validity]} does not match expected #{@group.imap_uid_validity}, invalidating IMAP cache and resyncing emails for mailbox #{@group.imap_mailbox_name}", @group)
        @group.imap_last_uid = 0
      end

      if idle && !can_idle?
        ImapSyncLog.warn("IMAP server for group cannot IDLE or imap idle site setting is disabled", @group)
        idle = false
      end

      if idle
        raise 'IMAP IDLE is disabled' if !SiteSetting.enable_imap_idle

        # Thread goes into sleep and it is better to return any connection
        # back to the pool.
        ActiveRecord::Base.connection_handler.clear_active_connections!

        idle_polling_mins = SiteSetting.imap_polling_period_mins.minutes.to_i
        ImapSyncLog.debug("Going IDLE for #{idle_polling_mins} seconds to wait for more work", @group, db: false)

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

      ImapSyncLog.debug("Remote email server has #{old_uids.size} old emails and #{new_uids.size} new emails", @group)

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

      # if there are no old_uids that is OK, this could indicate that some
      # UIDs have been sent to the trash
      process_old_uids(old_uids)

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
      ImapSyncLog.debug("Syncing #{old_uids.size} randomly-selected old emails", @group)
      emails = old_uids.empty? ? [] : @provider.emails(old_uids, ['UID', 'FLAGS', 'LABELS', 'ENVELOPE'])
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
            message_id: Email::MessageIdService.message_id_clean(email['ENVELOPE'].message_id),
            imap_uid: nil,
            imap_uid_validity: nil
          ).where("to_addresses LIKE ?", "%#{@group.email_username}%").first

          if incoming_email
            incoming_email.update(
              imap_uid_validity: @status[:uid_validity],
              imap_uid: email['UID'],
              imap_group_id: @group.id
            )
            update_topic(email, incoming_email, mailbox_name: @group.imap_mailbox_name)
          else
            ImapSyncLog.warn("Could not find old email (UIDVALIDITY = #{@status[:uid_validity]}, UID = #{email['UID']})", @group)
          end
        end
      end

      handle_missing_uids(old_uids)
    end

    def handle_missing_uids(old_uids)
      # If there are any UIDs for the mailbox missing from old_uids, this means they have been moved
      # to some other mailbox in the mail server. They could be possibly deleted. first we can check
      # if they have been deleted and if so delete the associated post/topic. then the remaining we
      # can just remove the imap details from the IncomingEmail table and if they end up back in the
      # original mailbox then they will be picked up in a future resync.
      existing_incoming = IncomingEmail.includes(:post).where(
        imap_group_id: @group.id, imap_uid_validity: @status[:uid_validity]
      ).where.not(imap_uid: nil)

      existing_uids = existing_incoming.map(&:imap_uid)
      missing_uids = existing_uids - old_uids
      missing_message_ids = existing_incoming.select do |incoming|
        missing_uids.include?(incoming.imap_uid)
      end.map(&:message_id)

      return if missing_message_ids.empty?

      # This can be done because Message-ID is unique on a mail server between mailboxes,
      # where the UID will have changed when moving into the Trash mailbox. We need to get
      # the new UID from the trash.
      potential_spam = []
      response = @provider.find_trashed_by_message_ids(missing_message_ids)
      existing_incoming.each do |incoming|
        matching_trashed = response.trashed_emails.find { |email| email.message_id == incoming.message_id }

        if !matching_trashed
          potential_spam << incoming
          next
        end

        # if we deleted the topic/post ourselves in discourse then the post will
        # not exist, and this sync is just updating the old UIDs to the new ones
        # in the trash, and we don't need to re-destroy the post
        if incoming.post
          ImapSyncLog.debug("Deleting post ID #{incoming.post_id}, topic id #{incoming.topic_id}; email has been deleted on the IMAP server.", @group)
          PostDestroyer.new(Discourse.system_user, incoming.post).destroy
        end

        # the email has moved mailboxes, we don't want to try trashing again next time
        ImapSyncLog.debug("Updating incoming ID #{incoming.id} uid data FROM [UID #{incoming.imap_uid} | UIDVALIDITY #{incoming.imap_uid_validity}] TO [UID #{matching_trashed.uid} | UIDVALIDITY #{response.trash_uid_validity}] (TRASHED)", @group)
        incoming.update(imap_uid_validity: response.trash_uid_validity, imap_uid: matching_trashed.uid)
      end

      # This can be done because Message-ID is unique on a mail server between mailboxes,
      # where the UID will have changed when moving into the Trash mailbox. We need to get
      # the new UID from the spam.
      response = @provider.find_spam_by_message_ids(missing_message_ids)
      potential_spam.each do |incoming|
        matching_spam = response.spam_emails.find { |email| email.message_id == incoming.message_id }

        # if the email is not in the trash or spam then we don't know where it is... could
        # be in any mailbox on the server or could be permanently deleted.
        if !matching_spam
          ImapSyncLog.debug("Email for incoming ID #{incoming.id} (#{incoming.message_id}) could not be found in the group mailbox, trash, or spam. It could be in another mailbox or permanently deleted.", @group)
          incoming.update(imap_missing: true)
          next
        end

        # if we deleted the topic/post ourselves in discourse then the post will
        # not exist, and this sync is just updating the old UIDs to the new ones
        # in the spam, and we don't need to re-destroy the post
        if incoming.post
          ImapSyncLog.debug("Deleting post ID #{incoming.post_id}, topic id #{incoming.topic_id}; email has been moved to spam on the IMAP server.", @group)
          PostDestroyer.new(Discourse.system_user, incoming.post).destroy
        end

        # the email has moved mailboxes, we don't want to try marking as spam again next time
        ImapSyncLog.debug("Updating incoming ID #{incoming.id} uid data FROM [UID #{incoming.imap_uid} | UIDVALIDITY #{incoming.imap_uid_validity}] TO [UID #{matching_spam.uid} | UIDVALIDITY #{response.spam_uid_validity}] (SPAM)", @group)
        incoming.update(imap_uid_validity: response.spam_uid_validity, imap_uid: matching_spam.uid)
      end
    end

    def process_new_uids(new_uids, import_mode, all_old_uids_size, all_new_uids_size)
      ImapSyncLog.debug("Syncing #{new_uids.size} new emails (oldest first)", @group)

      emails = @provider.emails(new_uids, ['UID', 'FLAGS', 'LABELS', 'RFC822'])
      processed = 0

      # TODO (maybe): We might need something here to exclusively handle
      # the UID of the incoming email, so we don't end up with a race condition
      # where the same UID is handled multiple times before the group imap_X
      # columns are updated.
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
            imap_group_id: @group.id,
            source: :imap
          )
          receiver.process!

          update_topic(email, receiver.incoming_email, mailbox_name: @group.imap_mailbox_name)
        rescue Email::Receiver::ProcessingError => e
          ImapSyncLog.warn("Could not process (UIDVALIDITY = #{@status[:uid_validity]}, UID = #{email['UID']}): #{e.message}", @group)
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
          ImapSyncLog.debug("Updating email on IMAP server for incoming email ID = #{incoming_email.id}, UID = #{incoming_email.imap_uid}", @group)
          update_email(incoming_email)
          incoming_email.update(imap_sync: false)
        end
      end
    end

    def update_topic_archived_state(email, incoming_email, opts = {})
      topic = incoming_email.topic

      topic_is_archived = topic.group_archived_messages.size > 0
      email_is_archived = !email['LABELS'].include?('\\Inbox') && !email['LABELS'].include?('INBOX')

      if topic_is_archived && !email_is_archived
        ImapSyncLog.debug("Unarchiving topic ID #{topic.id}, email was unarchived", @group)
        GroupArchivedMessage.move_to_inbox!(@group.id, topic, skip_imap_sync: true)
      elsif !topic_is_archived && email_is_archived
        ImapSyncLog.debug("Archiving topic ID #{topic.id}, email was archived", @group)
        GroupArchivedMessage.archive!(@group.id, topic, skip_imap_sync: true)
      end
    end

    def update_topic_tags(email, incoming_email, opts = {})
      group_email_regex = @group.email_username_regex
      topic = incoming_email.topic

      tags = Set.new

      # "Plus" part from the destination email address
      to_addresses = incoming_email.to_addresses_split
      cc_addresses = incoming_email.cc_addresses_split
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

      return if !tagging_enabled?

      # TODO: Optimize tagging.
      # `DiscourseTagging.tag_topic_by_names` does a lot of lookups in the
      # database and some of them could be cached in this context.
      DiscourseTagging.tag_topic_by_names(topic, Guardian.new(Discourse.system_user), tags.to_a)
    end

    def update_email(incoming_email)
      return if !incoming_email || !incoming_email.imap_sync

      post = incoming_email.post
      if !post && incoming_email.post_id
        # post was likely deleted because topic was deleted, let's try get it
        post = Post.with_deleted.find(incoming_email.post_id)
      end

      # don't do any of these type of updates on anything but the OP in the
      # email thread -- archiving and deleting will be handled for the whole
      # thread depending on provider
      return if post&.post_number != 1
      topic = incoming_email.topic

      # if email is nil, the UID does not exist in the provider, meaning....
      #
      # A) the email has been deleted/moved to a different mailbox in the provider
      # B) the UID does not belong to the provider
      email = @provider.emails(incoming_email.imap_uid, ['FLAGS', 'LABELS']).first
      return if !email.present?

      labels = email['LABELS']
      flags = email['FLAGS']
      new_labels = []
      new_flags = []

      # Topic has been deleted if it is not present from the post, so we need
      # to trash the IMAP server email
      if !topic
        # no need to do anything further here, we will recognize the UIDs in the
        # mail server email thread have been trashed on next sync
        ImapSyncLog.debug("Trashing UID #{incoming_email.imap_uid} (incoming ID #{incoming_email.id})", @group)
        return @provider.trash(incoming_email.imap_uid)
      end

      # the topic is archived, and the archive should be reflected in the IMAP
      # server
      topic_archived = topic.group_archived_messages.any?
      if !topic_archived
        # TODO: This is needed right now so the store below does not take it
        # away again...ideally we should unarchive and store the tag-labels
        # at the same time.
        new_labels << "\\Inbox"

        ImapSyncLog.debug("Unarchiving UID #{incoming_email.imap_uid} (incoming ID #{incoming_email.id})", @group)

        # some providers need special handling for unarchiving too
        @provider.unarchive(incoming_email.imap_uid)
      else
        ImapSyncLog.debug("Archiving UID #{incoming_email.imap_uid} (incoming ID #{incoming_email.id})", @group)

        # some providers need special handling for archiving. this way we preserve
        # any new tag-labels, and archive, even though it may cause extra requests
        # to the IMAP server
        @provider.archive(incoming_email.imap_uid)
      end

      # Sync topic status and labels with email flags and labels.
      if tagging_enabled?
        tags = topic.tags.pluck(:name)
        new_flags = tags.map { |tag| @provider.tag_to_flag(tag) }.reject(&:blank?)
        new_labels = new_labels.concat(tags.map { |tag| @provider.tag_to_label(tag) }.reject(&:blank?))
      end

      # regardless of whether the topic needs to be archived we still update
      # the flags and the labels
      @provider.store(incoming_email.imap_uid, 'FLAGS', flags, new_flags)
      @provider.store(incoming_email.imap_uid, 'LABELS', labels, new_labels)
    end

    def tagging_enabled?
      SiteSetting.tagging_enabled && SiteSetting.allow_staff_to_tag_pms
    end
  end
end
