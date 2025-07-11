# frozen_string_literal: true

module DiscourseTemplatesSpecHelpers
  # keep this list synchronized with the list in assets/javascripts/lib/replace-variables.js
  TEMPLATES_ALLOWED_VARIABLES =
    Set.new(
      %w[
        my_username
        my_name
        chat_channel_name
        chat_channel_url
        chat_thread_name
        chat_thread_url
        context_title
        context_url
        topic_title
        topic_url
        original_poster_username
        original_poster_name
        reply_to_username
        reply_to_name
        last_poster_username
        reply_to_or_last_poster_username
      ],
    )

  def templates_allowed_variables
    TEMPLATES_ALLOWED_VARIABLES
  end
end

RSpec.configure { |config| config.include DiscourseTemplatesSpecHelpers }
