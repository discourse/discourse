require 'google/apis/gmail_v1'
require 'googleauth'
require_dependency 'gmail_sync'
require_dependency 'imap'

module Jobs
  class ProcessGmail < Jobs::Base
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

      sync = Imap::Sync.new(group, Imap::Providers::Gmail)
      last_history_id = group.custom_fields[GmailSync::HISTORY_ID_FIELD] || args[:history_id]
      page_token = nil

      loop do
        list = service.list_user_histories(args[:email_address], start_history_id: last_history_id, page_token: page_token)
        (list.history || []).each do |history|
          (history.messages || []).each do |message|
            begin
              message = service.get_user_message(args[:email_address], message.id, format: 'raw')
              email = {
                "UID" => message.id,
                "FLAGS" => [],
                "LABELS" => message.label_ids,
                "RFC822" => message.raw,
              }

              receiver = Email::Receiver.new(email["RFC822"],
                destinations: [{ type: :group, obj: group }],
                uid_validity: args[:history_id],
                uid: -1
              )
              receiver.process!
              sync.update_topic(email, receiver.incoming_email)
            rescue Email::Receiver::ProcessingError => e
            end
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
