require 'google/apis/gmail_v1'
require 'googleauth'
require_dependency 'gmail_sync'
require_dependency 'imap'

module Jobs
  class ProcessGmailHistory < Jobs::Base
    def execute(args)
      @args = args || {}

      group = Group.find_by(email_username: args[:email_address])
      if !group
        Rails.logger.warn("No group was found for email address: #{args[:email_address]}.")
        return
      end

      service = GmailSync.service_for(group)
      if !service
        Rails.logger.warn("Cannot get GMail service for email address: #{args[:email_address]}.")
        return
      end

      last_history_id = group.custom_fields[GmailSync::HISTORY_ID_FIELD] || args[:history_id]
      page_token = nil

      loop do
        list = service.list_user_histories(args[:email_address], start_history_id: last_history_id, page_token: page_token)
        (list.history || []).each do |history|
          (history.messages || []).each do |message|
            message = service.get_user_message(args[:email_address], message.id, format: "raw")

            Jobs.enqueue(:sync_imap_email,
              group_id: group.id,
              mailbox_name: mailbox.name,
              uid_validity: -1,
              email: {
                "UID" => message.id,
                "FLAGS" => [],
                "LABELS" => message.label_ids,
                "RFC822" => Base64.encode64(message.raw),
              }
            )
          end

          last_history_id = history.id
        end

        page_token = list.next_page_token
        break if page_token == nil
      end

      group.custom_fields[GmailSync::HISTORY_ID_FIELD] = last_history_id
      group.save_custom_fields

      nil
    end
  end
end
