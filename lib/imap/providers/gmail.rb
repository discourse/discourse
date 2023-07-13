# frozen_string_literal: true

module Imap
  module Providers
    # Gmail has a special header for both labels (X-GM-LABELS) and their
    # threading system (X-GM-THRID). We need to monkey-patch Net::IMAP to
    # get access to these. Also the archiving functionality is custom,
    # all UIDs in a thread must have the \\Inbox label removed.
    #
    class Gmail < Generic
      X_GM_LABELS = "X-GM-LABELS"
      X_GM_THRID = "X-GM-THRID"

      def imap
        @imap ||= super.tap { |imap| apply_gmail_patch(imap) }
      end

      def emails(uids, fields, opts = {})
        # gmail has a special header for labels
        fields[fields.index("LABELS")] = X_GM_LABELS if fields.include?("LABELS")

        emails = super(uids, fields, opts)

        emails.each do |email|
          email["LABELS"] = Array(email["LABELS"])

          if email[X_GM_LABELS]
            email["LABELS"] << Array(email.delete(X_GM_LABELS))
            email["LABELS"].flatten!
          end

          email["LABELS"] << '\\Inbox' if @open_mailbox_name == "INBOX"

          email["LABELS"].uniq!
        end

        emails
      end

      def store(uid, attribute, old_set, new_set)
        attribute = X_GM_LABELS if attribute == "LABELS"
        super(uid, attribute, old_set, new_set)
      end

      def to_tag(label)
        # Label `\\Starred` is Gmail equivalent of :Flagged (both present)
        return "starred" if label == :Flagged
        return if label == "[Gmail]/All Mail"

        label = label.to_s.gsub("[Gmail]/", "")
        super(label)
      end

      def tag_to_flag(tag)
        return :Flagged if tag == "starred"

        super(tag)
      end

      def tag_to_label(tag)
        return '\\Important' if tag == "important"
        return '\\Starred' if tag == "starred"

        super(tag)
      end

      # All emails in the thread must be archived in Gmail for the thread
      # to get removed from the inbox
      def archive(uid)
        thread_id = thread_id_from_uid(uid)
        emails_to_archive = emails_in_thread(thread_id)
        emails_to_archive.each do |email|
          labels = email["LABELS"]
          new_labels = labels.reject { |l| l == "\\Inbox" }
          store(email["UID"], "LABELS", labels, new_labels)
        end
        ImapSyncLog.log(
          "Thread ID #{thread_id} (UID #{uid}) archived in Gmail mailbox for #{@username}",
          :debug,
        )
      end

      # Though Gmail considers the email thread unarchived if the first email
      # has the \\Inbox label applied, we want to do this to all emails in the
      # thread to be consistent with archive behaviour.
      def unarchive(uid)
        thread_id = thread_id_from_uid(uid)
        emails_to_unarchive = emails_in_thread(thread_id)
        emails_to_unarchive.each do |email|
          labels = email["LABELS"]
          new_labels = labels.dup
          new_labels << "\\Inbox" if !new_labels.include?("\\Inbox")
          store(email["UID"], "LABELS", labels, new_labels)
        end
        ImapSyncLog.log(
          "Thread ID #{thread_id} (UID #{uid}) unarchived in Gmail mailbox for #{@username}",
          :debug,
        )
      end

      def thread_id_from_uid(uid)
        fetched = imap.uid_fetch(uid, [X_GM_THRID])
        raise "Thread not found for UID #{uid}!" if !fetched

        fetched.last.attr[X_GM_THRID]
      end

      def emails_in_thread(thread_id)
        uids_to_fetch = imap.uid_search("#{X_GM_THRID} #{thread_id}")
        emails(uids_to_fetch, %w[UID LABELS])
      end

      def trash_move(uid)
        thread_id = thread_id_from_uid(uid)
        email_uids_to_trash = emails_in_thread(thread_id).map { |e| e["UID"] }

        imap.uid_move(email_uids_to_trash, trash_mailbox)
        ImapSyncLog.log(
          "Thread ID #{thread_id} (UID #{uid}) trashed in Gmail mailbox for #{@username}",
          :debug,
        )
        { trash_uid_validity: open_trash_mailbox, email_uids_to_trash: email_uids_to_trash }
      end

      # Some mailboxes are just not useful or advisable to sync with. This is
      # used for the dropdown in the UI where we allow the user to select the
      # IMAP mailbox to sync with.
      def filter_mailboxes(mailboxes_with_attributes)
        mailboxes_with_attributes
          .reject { |mb| (mb.attr & %i[Drafts Sent Junk Flagged Trash]).any? }
          .map(&:name)
      end

      private

      def apply_gmail_patch(imap)
        class << imap.instance_variable_get("@parser")
          # Modified version of the original `msg_att` from here:
          # https://github.com/ruby/ruby/blob/1cc8ff001da217d0e98d13fe61fbc9f5547ef722/lib/net/imap.rb#L2346
          #
          # This is done so we can extract X-GM-LABELS, X-GM-MSGID, and
          # X-GM-THRID, all Gmail extended attributes.
          #
          # rubocop:disable Style/RedundantReturn
          def msg_att(n)
            match(T_LPAR)
            attr = {}
            while true
              token = lookahead
              case token.symbol
              when T_RPAR
                shift_token
                break
              when T_SPACE
                shift_token
                next
              end
              case token.value
              when /\A(?:ENVELOPE)\z/ni
                name, val = envelope_data
              when /\A(?:FLAGS)\z/ni
                name, val = flags_data
              when /\A(?:INTERNALDATE)\z/ni
                name, val = internaldate_data
              when /\A(?:RFC822(?:\.HEADER|\.TEXT)?)\z/ni
                name, val = rfc822_text
              when /\A(?:RFC822\.SIZE)\z/ni
                name, val = rfc822_size
              when /\A(?:BODY(?:STRUCTURE)?)\z/ni
                name, val = body_data
              when /\A(?:UID)\z/ni
                name, val = uid_data
              when /\A(?:MODSEQ)\z/ni
                name, val = modseq_data

                # Adding support for GMail extended attributes.
              when /\A(?:X-GM-LABELS)\z/ni
                name, val = label_data
              when /\A(?:X-GM-MSGID)\z/ni
                name, val = uid_data
              when /\A(?:X-GM-THRID)\z/ni
                name, val = uid_data
                # End custom support for Gmail.
              else
                parse_error("unknown attribute `%s' for {%d}", token.value, n)
              end
              attr[name] = val
            end
            return attr
          end

          def label_data
            token = match(T_ATOM)
            name = token.value.upcase

            match(T_SPACE)
            match(T_LPAR)

            result = []
            while true
              token = lookahead
              case token.symbol
              when T_RPAR
                shift_token
                break
              when T_SPACE
                shift_token
              end

              token = lookahead
              if string_token?(token)
                result.push(string)
              else
                result.push(atom)
              end
            end
            return name, result
          end
          # rubocop:enable Style/RedundantReturn
        end
      end
    end
  end
end
