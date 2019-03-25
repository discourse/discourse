require 'google/apis/gmail_v1'
require 'googleauth'
require_dependency 'gmail_sync'

module Jobs
  class WatchGmail < Jobs::Scheduled
    every 1.day

    sidekiq_options retry: false

    def execute(args)
      Group.all.each do |group|
        service = GmailSync.service_for(group)
        next if !service

        topic_name = group.custom_fields[GmailSync::TOPIC_NAME_FIELD]
        next if !topic_name

        result = service.watch_user(user_id, Google::Apis::GmailV1::WatchRequest.new(topic_name: topic_name))

        if !group.custom_fields[GmailSync::HISTORY_ID_FIELD]
          group.custom_fields[GmailSync::HISTORY_ID_FIELD] = result.history_id
          group.save_custom_fields
        end
      end

      nil
    end
  end
end
