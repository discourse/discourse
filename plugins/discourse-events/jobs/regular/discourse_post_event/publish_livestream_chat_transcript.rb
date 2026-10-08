# frozen_string_literal: true

module Jobs
  class PublishLivestreamChatTranscript < ::Jobs::Base
    def execute(args)
      DiscourseEvents::Livestream::PublishChatTranscript.call(
        params: {
          event_date_id: args[:event_date_id],
        },
      )
    end
  end
end
