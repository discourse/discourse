# frozen_string_literal: true

module Jobs
  class PublishLivestreamChatTranscript < ::Jobs::Base
    MAX_ATTEMPTS = 3

    def execute(args)
      attempts = 0
      begin
        DiscourseEvents::Livestream::PublishChatTranscript.call(
          params: {
            event_date_id: args[:event_date_id],
          },
        )
      rescue DiscourseEvents::Livestream::PublishChatTranscript::EventPostChanged
        retry if (attempts += 1) < MAX_ATTEMPTS
        raise
      end
    end
  end
end
