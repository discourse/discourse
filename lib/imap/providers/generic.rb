# frozen_string_literal: true

require 'net/imap'

module Imap
  module Providers
    class WriteDisabledError < StandardError; end

    class TrashedMailResponse
      attr_accessor :trashed_emails, :trash_uid_validity
    end

    class SpamMailResponse
      attr_accessor :spam_emails, :spam_uid_validity
    end

    class BasicMail
      attr_accessor :uid, :message_id

      def initialize(uid: nil, message_id: nil)
        @uid = uid
        @message_id = message_id
      end
    end

    class Generic
      def initialize(server, options = {})
        @server = server
        @port = options[:port] || 993
        @ssl = options[:ssl] || true
        @username = options[:username]
        @password = options[:password]
        @timeout = options[:timeout] || 10
      end

      def account_digest
        @account_digest ||= Digest::MD5.hexdigest("#{@username}:#{@server}")
      end

      def imap
        @imap ||= Net::IMAP.new(@server, port: @port, ssl: @ssl, open_timeout: @timeout)
      end

      def disconnected?
        @imap && @imap.disconnected?
      end

      def connect!
        imap.login(@username, @password)
      end

      def disconnect!
        imap.logout rescue nil
        imap.disconnect
      end

      def can?(capability)
        @capabilities ||= imap.responses['CAPABILITY'][-1] || imap.capability
        @capabilities.include?(capability)
      end

      def uids(opts = {})
        if opts[:from] && opts[:to]
          imap.uid_search("UID #{opts[:from]}:#{opts[:to]}")
        elsif opts[:from]
          imap.uid_search("UID #{opts[:from]}:*")
        elsif opts[:to]
          imap.uid_search("UID 1:#{opts[:to]}")
        else
          imap.uid_search('ALL')
        end
      end

      def labels
        @labels ||= begin
          labels = {}

          list_mailboxes.each do |name|
            if tag = to_tag(name)
              labels[tag] = name
            end
          end

          labels
        end
      end

      def open_mailbox(mailbox_name, write: false)
        if write
          if !SiteSetting.enable_imap_write
            raise WriteDisabledError.new("Two-way IMAP sync is disabled! Cannot write to inbox.")
          end
          imap.select(mailbox_name)
        else
          imap.examine(mailbox_name)
        end

        @open_mailbox_name = mailbox_name
        @open_mailbox_write = write

        {
          uid_validity: imap.responses['UIDVALIDITY'][-1]
        }
      end

      def emails(uids, fields, opts = {})
        fetched = imap.uid_fetch(uids, fields)

        # This will happen if the email does not exist in the provided mailbox.
        # It may have been deleted or otherwise moved, e.g. if deleted in Gmail
        # it will end up in "[Gmail]/Bin"
        return [] if fetched.nil?

        fetched.map do |email|
          attributes = {}

          fields.each do |field|
            attributes[field] = email.attr[field]
          end

          attributes
        end
      end

      def store(uid, attribute, old_set, new_set)
        additions = new_set.reject { |val| old_set.include?(val) }
        imap.uid_store(uid, "+#{attribute}", additions) if additions.length > 0
        removals = old_set.reject { |val| new_set.include?(val) }
        imap.uid_store(uid, "-#{attribute}", removals) if removals.length > 0
      end

      def to_tag(label)
        label = DiscourseTagging.clean_tag(label.to_s)
        label if label != 'inbox' && label != 'sent'
      end

      def tag_to_flag(tag)
        :Seen if tag == 'seen'
      end

      def tag_to_label(tag)
        tag
      end

      def list_mailboxes(attr_filter = nil)
        # Lists all the mailboxes but just returns the names.
        list_mailboxes_with_attributes(attr_filter).map(&:name)
      end

      def list_mailboxes_with_attributes(attr_filter = nil)
        # Basically, list all mailboxes in the root of the server.
        # ref: https://tools.ietf.org/html/rfc3501#section-6.3.8
        imap.list('', '*').reject do |m|

          # Noselect cannot be selected with the SELECT command.
          # technically we could use this for readonly mode when
          # SiteSetting.imap_write is disabled...maybe a later TODO
          # ref: https://tools.ietf.org/html/rfc3501#section-7.2.2
          m.attr.include?(:Noselect)
        end.select do |m|

          # There are Special-Use mailboxes denoted by an attribute. For
          # example, some common ones are \Trash or \Sent.
          # ref: https://tools.ietf.org/html/rfc6154
          if attr_filter
            m.attr.include? attr_filter
          else
            true
          end
        end
      end

      def filter_mailboxes(mailboxes)
        # we do not want to filter out any mailboxes for generic providers,
        # because we do not know what they are ahead of time
        mailboxes
      end

      def archive(uid)
        # do nothing by default, just removing the Inbox label should be enough
      end

      def unarchive(uid)
        # same as above
      end

      # Look for the special Trash XLIST attribute.
      def trash_mailbox
        Discourse.cache.fetch("imap_trash_mailbox_#{account_digest}", expires_in: 30.minutes) do
          list_mailboxes(:Trash).first
        end
      end

      # Look for the special Junk XLIST attribute.
      def spam_mailbox
        Discourse.cache.fetch("imap_spam_mailbox_#{account_digest}", expires_in: 30.minutes) do
          list_mailboxes(:Junk).first
        end
      end

      # open the trash mailbox for inspection or writing. after the yield we
      # close the trash and reopen the original mailbox to continue operations.
      # the normal open_mailbox call can be made if more extensive trash ops
      # need to be done.
      def open_trash_mailbox(write: false)
        open_mailbox_before_trash = @open_mailbox_name
        open_mailbox_before_trash_write = @open_mailbox_write

        trash_uid_validity = open_mailbox(trash_mailbox, write: write)[:uid_validity]

        yield(trash_uid_validity) if block_given?

        open_mailbox(open_mailbox_before_trash, write: open_mailbox_before_trash_write)
        trash_uid_validity
      end

      # open the spam mailbox for inspection or writing. after the yield we
      # close the spam and reopen the original mailbox to continue operations.
      # the normal open_mailbox call can be made if more extensive spam ops
      # need to be done.
      def open_spam_mailbox(write: false)
        open_mailbox_before_spam = @open_mailbox_name
        open_mailbox_before_spam_write = @open_mailbox_write

        spam_uid_validity = open_mailbox(spam_mailbox, write: write)[:uid_validity]

        yield(spam_uid_validity) if block_given?

        open_mailbox(open_mailbox_before_spam, write: open_mailbox_before_spam_write)
        spam_uid_validity
      end

      def find_trashed_by_message_ids(message_ids)
        trashed_emails = []
        trash_uid_validity = open_trash_mailbox do
          trashed_email_uids = find_uids_by_message_ids(message_ids)
          if trashed_email_uids.any?
            trashed_emails = emails(trashed_email_uids, ["UID", "ENVELOPE"]).map do |e|
              BasicMail.new(message_id: Email::MessageIdService.message_id_clean(e['ENVELOPE'].message_id), uid: e['UID'])
            end
          end
        end

        TrashedMailResponse.new.tap do |resp|
          resp.trashed_emails = trashed_emails
          resp.trash_uid_validity = trash_uid_validity
        end
      end

      def find_spam_by_message_ids(message_ids)
        spam_emails = []
        spam_uid_validity = open_spam_mailbox do
          spam_email_uids = find_uids_by_message_ids(message_ids)
          if spam_email_uids.any?
            spam_emails = emails(spam_email_uids, ["UID", "ENVELOPE"]).map do |e|
              BasicMail.new(message_id: Email::MessageIdService.message_id_clean(e['ENVELOPE'].message_id), uid: e['UID'])
            end
          end
        end

        SpamMailResponse.new.tap do |resp|
          resp.spam_emails = spam_emails
          resp.spam_uid_validity = spam_uid_validity
        end
      end

      def find_uids_by_message_ids(message_ids)
        header_message_id_terms = message_ids.map do |msgid|
          "HEADER Message-ID '#{Email::MessageIdService.message_id_rfc_format(msgid)}'"
        end

        # OR clauses are written in Polish notation...so the query looks like this:
        # OR OR HEADER Message-ID XXXX HEADER Message-ID XXXX HEADER Message-ID XXXX
        or_clauses = 'OR ' * (header_message_id_terms.length - 1)
        query = "#{or_clauses}#{header_message_id_terms.join(" ")}"

        imap.uid_search(query)
      end

      def trash(uid)
        # MOVE is way easier than doing the COPY \Deleted EXPUNGE dance ourselves.
        # It is supported by Gmail and Outlook.
        if can?('MOVE')
          trash_move(uid)
        else

          # default behaviour for IMAP servers is to add the \Deleted flag
          # then EXPUNGE the mailbox which permanently deletes these messages
          # https://tools.ietf.org/html/rfc3501#section-6.4.3
          #
          # TODO: We may want to add the option at some point to copy to some
          # other mailbox first before doing this (e.g. Trash)
          store(uid, 'FLAGS', [], ["\\Deleted"])
          imap.expunge
        end
      end

      def trash_move(uid)
        # up to the provider
      end
    end
  end
end
