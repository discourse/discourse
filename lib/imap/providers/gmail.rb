# frozen_string_literal: true

module Imap
  module Providers
    class Gmail < Generic
      X_GM_LABELS = 'X-GM-LABELS'

      def imap
        @imap ||= super.tap { |imap| apply_gmail_patch(imap) }
      end

      def emails(uids, fields, opts = {})
        fields[fields.index('LABELS')] = X_GM_LABELS

        emails = super(uids, fields, opts)

        emails.each do |email|
          email['LABELS'] = Array(email['LABELS'])

          if email[X_GM_LABELS]
            email['LABELS'] << Array(email.delete(X_GM_LABELS))
            email['LABELS'].flatten!
          end

          email['LABELS'] << '\\Inbox' if opts[:mailbox] == 'INBOX'

          email['LABELS'].uniq!
        end

        emails
      end

      def store(uid, attribute, old_set, new_set)
        attribute = X_GM_LABELS if attribute == 'LABELS'
        super(uid, attribute, old_set, new_set)
      end

      def to_tag(label)
        # Label `\\Starred` is Gmail equivalent of :Flagged (both present)
        return 'starred' if label == :Flagged
        return if label == '[Gmail]/All Mail'

        label = label.to_s.gsub('[Gmail]/', '')
        super(label)
      end

      def tag_to_flag(tag)
        return :Flagged if tag == 'starred'

        super(tag)
      end

      def tag_to_label(tag)
        return '\\Important' if tag == 'important'
        return '\\Starred' if tag == 'starred'

        super(tag)
      end

      private

      def apply_gmail_patch(imap)
        class << imap.instance_variable_get('@parser')

          # Modified version of the original `msg_att` from here:
          # https://github.com/ruby/ruby/blob/1cc8ff001da217d0e98d13fe61fbc9f5547ef722/lib/net/imap.rb#L2346
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
